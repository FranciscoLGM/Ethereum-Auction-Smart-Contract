// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/**
 * @title Smart Contract Auction
 * @dev Implements an ETH auction system with partial refunds, commission fees, and automatic time extensions
 * @author Francisco López G
 */
contract Auction {
    // ==============================================
    //                   STRUCTS
    // ==============================================

    /// @dev Structure for storing bidder information
    /// @param bidderAddress Address of the bidder
    /// @param amount Amount bid by the address
    struct Bidder {
        address bidderAddress;
        uint256 amount;
    }

    // ==============================================
    //                STATE VARIABLES
    // ==============================================

    /// @notice Contract owner address
    address public owner;

    /// @notice Timestamp when the auction will end
    uint256 public endTime;

    /// @notice Minimum percentage increase for new bids (e.g., 105 = 5% increase)
    uint256 public minIncrease;

    /// @notice Commission rate percentage taken from refunds
    uint256 public commissionRate;

    /// @notice Time extension applied when bids are placed near end
    uint256 public extensionTime;

    /// @notice Total commission accumulated from refunds
    uint256 public totalCommission;

    /// @notice Minimum initial bid value (1 ETH), required for the first bid
    uint256 public initBid;

    /// @notice Flag indicating if auction has been ended
    bool public isEnded;

    /// @notice Flag indicating if all refunds have been processed
    bool public refundsProcessed;

    /// @notice Current highest bidder information
    Bidder public highestBidder;

    /// @notice Information about the auction winner and the winning bid
    Bidder public winner;

    /// @notice Mapping of addresses to their pending refund amounts
    mapping(address => uint256) public pendingRefunds;

    /// @notice Array of all bids placed in the auction
    Bidder[] private allBids;

    // ==============================================
    //                   EVENTS
    // ==============================================

    /**
     * @notice Emitted when a new bid is placed
     * @param bidder Address of the bidder
     * @param amount Amount of the bid
     */
    event NewBid(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when auction ends
     * @param winner Address of the winning bidder
     * @param amount Winning bid amount
     */
    event AuctionEnded(address indexed winner, uint256 amount);

    /**
     * @notice Emitted when a partial refund is processed
     * @param bidder Address receiving refund
     * @param amount Full refund amount (no commission)
     */
    event PartialRefund(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when a full refund is processed
     * @param bidder Address receiving refund
     * @param amount Refund amount after commission
     */
    event BidRefunded(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when the owner withdraws the winning bid amount
     * @param owner Address of the contract owner receiving funds
     * @param amount Amount withdrawn (full winning bid amount)
     */
    event OwnerWithdrawal(address indexed owner, uint256 amount);

    /**
     * @notice Emitted when owner performs emergency withdrawal of all contract funds
     * @param owner Address of the contract owner receiving funds
     * @param amount Total amount withdrawn from contract
     */
    event EmergencyWithdrawal(address indexed owner, uint256 amount);

    /**
     * @notice Emitted when the auction is force-terminated by the owner before endTime
     * @dev Replaces AuctionEnded in emergency cases
     */
    event AuctionForceEnded(address indexed Bidder, uint256 amount);

    // ==============================================
    //                 MODIFIERS
    // ==============================================

    /// @dev Modifier restricting access to contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @dev Modifier ensuring auction is still active
    modifier onlyActive() {
        require(block.timestamp < endTime, "Auction ended");
        require(!isEnded, "Terminated");
        _;
    }

    /// @dev Modifier ensuring auction has ended
    modifier onlyEnded() {
        require(block.timestamp >= endTime || isEnded, "Still active");
        _;
    }

    /// @dev Modifier preventing owner from bidding
    modifier nonOwner() {
        require(msg.sender != owner, "Not allowed");
        _;
    }

    // ==============================================
    //              CONSTRUCTOR
    // ==============================================

    /**
     * @notice Contract constructor initializing auction parameters
     * @dev Sets default auction parameters (7 day duration, 5% min increase, 2% commission)
     * @dev The owner is set to the contract deployer
     */
    constructor() {
        owner = msg.sender;
        endTime = block.timestamp + 7 days;
        minIncrease = 105; // 5% minimum increase
        commissionRate = 2; // 2% commission
        extensionTime = 10 minutes;
        initBid = 1 ether; // Initial value 1 ETH
        isEnded = false;
    }

    // ==============================================
    //              PUBLIC FUNCTIONS
    // ==============================================

    /**
     * @notice Places a bid in the auction
     * @dev Bid must be at least 5% higher than current highest bid
     * @dev Extends auction time if bid is placed within last 10 minutes
     * @dev Emits NewBid event on successful bid
     * @dev Automatically finalizes auction if time has expired
     * @dev Reverts if:
     *      - Auction is not active
     *      - Bid amount is zero
     *      - Bid doesn't meet minimum increase requirement
     *      - Sender is the owner
     */
    function bid() external payable onlyActive nonOwner {
        require(msg.value >= initBid, "Min 1 ETH");

        // Copy highestBidder to a local variable in memory (cheaper on gas)
        Bidder memory currentHighestBidder = highestBidder;
        require(
            msg.value >= (currentHighestBidder.amount * minIncrease) / 100,
            "Bid too low"
        );

        address prevBidder = currentHighestBidder.bidderAddress;
        uint256 prevAmount = currentHighestBidder.amount;

        // If there is a previous bid, add it to pending refunds
        if (prevBidder != address(0)) {
            pendingRefunds[prevBidder] += prevAmount;
        }

        // Register the offer
        highestBidder = Bidder(msg.sender, msg.value);
        allBids.push(highestBidder);

        // Extend the auction if the bid arrives in the last 10 minutes
        if (endTime - block.timestamp < extensionTime) {
            endTime += extensionTime;
        }

        emit NewBid(msg.sender, msg.value);

        // End auction if time has expired
        if (block.timestamp >= endTime) {
            _finalizeAuction();
        }
    }

    /**
     * @notice Get winner information
     * @dev Only available after auction ends
     * @return Address and amount of winning bid
     * @dev Reverts if auction is still active
     */
    function getWinner() external view onlyEnded returns (address, uint256) {
        return (winner.bidderAddress, winner.amount);
    }

    /**
     * @notice Get all bids placed in auction
     * @return Array of Bidder structs containing all bids
     */
    function getAllBids() external view returns (Bidder[] memory) {
        return allBids;
    }

    /**
     * @notice Withdraw refundable amounts during active auction
     * @dev Allows bidders to withdraw their outbid amounts before auction ends
     * @dev Emits PartialRefund event
     * @dev Reverts if:
     *      - Auction has ended
     *      - No refund available for sender
     *      - Transfer fails
     */
    function partialRefund() external onlyActive {
        uint256 refundable = pendingRefunds[msg.sender];
        require(refundable > 0, "No refund");
        pendingRefunds[msg.sender] = 0; // Prevent reentrancy

        (bool success, ) = payable(msg.sender).call{value: refundable}("");
        require(success, "Transfer failed");

        emit PartialRefund(msg.sender, refundable);
    }

    /**
     * @notice Ends the auction and declares the winner
     * @dev Allows the owner to end the auction after the end time has passed
     * @dev Emits `AuctionEnded` event with winner address and winning amount
     * @dev Reverts if:
     *      - Caller is not owner
     *      - Auction already ended
     *      - Auction end time hasn't been reached
     */
    function finalizeAuction() external onlyOwner {
        require(!isEnded, "Already ended");
        require(block.timestamp >= endTime, "Too early");
        _finalizeAuction();
    }

    /**
     * @notice Ends emergency auction (owner only)
     * @dev Marks the auction as ended and freezes the current winner
     * @dev Does not require time to have expired
     */
    function emergencyTerminate() external onlyOwner onlyActive {
        require(highestBidder.bidderAddress != address(0), "No bids");
        _finalizeAuction();
    }

    /**
     * @notice Get remaining auction time
     * @return secondsLeft Remaining time in seconds (0 if ended)
     */
    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= endTime || isEnded) return 0;
        return endTime - block.timestamp;
    }

    // ==============================================
    //             RESTRICTED FUNCTIONS
    // ==============================================

    /**
     * @notice Refunds all non-winning bidders automatically
     * @dev Only callable by owner after auction ends
     * @dev Processes all bids except the winning one
     * @dev Takes commission from each refund (2% by default)
     * @dev Emits BidRefunded event for each processed bid
     * @dev Reverts if:
     *      - Caller is not owner
     *      - Auction hasn't ended
     *      - Refunds already processed
     *      - Transfer fails
     */
    function refundAll() external onlyOwner onlyEnded {
        require(!refundsProcessed, "Refunds done");

        // Copy allBids to a local variable in memory (cheaper on gas)
        Bidder[] memory bids = allBids;

        address bidder;
        uint256 refundable;
        uint256 commission;
        uint256 tempCommission;
        uint256 toTransfer;
        uint256 totalBids = bids.length;

        for (uint256 i = 0; i < totalBids; i++) {
            bidder = bids[i].bidderAddress;
            if (bidder != winner.bidderAddress && pendingRefunds[bidder] > 0) {
                refundable = pendingRefunds[bidder];
                require(refundable > 0, "No refund");
                pendingRefunds[bidder] = 0; // Prevent reentrancy
                commission = (refundable * commissionRate) / 100; // Transfer with 2% commission
                tempCommission += commission;
                toTransfer = refundable - commission;

                (bool success, ) = payable(bidder).call{value: toTransfer}("");
                require(success, "Transfer failed");

                emit BidRefunded(bidder, toTransfer);
            }
        }
        totalCommission += tempCommission;
        refundsProcessed = true;
    }

    /**
     * @notice Withdraws the winning bid amount to the owner
     * @dev Can only be called by the owner after the auction has ended
     * @dev Transfers the full winning bid amount plus accumulated commissions to the contract owner
     * @dev Emits OwnerWithdrawal event
     * @dev Reverts if:
     *      - Caller is not owner
     *      - Auction hasn't ended
     *      - No funds to withdraw
     *      - Transfer fails
     */
    function claimWinningBid() external onlyOwner onlyEnded {
        require(highestBidder.amount > 0 || totalCommission > 0, "Withdrawn");
        uint256 amount = highestBidder.amount + totalCommission;
        highestBidder.amount = 0; // Prevent reentrancy
        totalCommission = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit OwnerWithdrawal(owner, amount);
    }

    /**
     * @notice Emergency withdrawal of all contract funds by owner
     * @dev Only callable by owner after auction ends
     * @dev Transfers entire contract balance to owner
     * @dev Emits EmergencyWithdrawal event
     * @dev Reverts if:
     *      - Caller is not owner
     *      - Auction hasn't ended
     *      - Contract balance is zero
     *      - Transfer fails
     */
    function emergencyWithdrawal() external onlyOwner onlyEnded {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Transfer failed");

        emit EmergencyWithdrawal(owner, balance);
    }

    // ==============================================
    //              INTERNAL FUNCTIONS
    // ==============================================

    /**
     * @dev Internal function to finalize the auction
     * @dev Sets auction state to ended and records winning bid information
     * @dev Emits AuctionEnded event
     */
    function _finalizeAuction() private {
        isEnded = true;
        winner = highestBidder;

        if (block.timestamp >= endTime) {
            emit AuctionEnded(winner.bidderAddress, winner.amount); // Normal termination
        } else {
            emit AuctionForceEnded(winner.bidderAddress, winner.amount); // Forced termination
        }
    }

    // ==============================================
    //      FALLBACK / RECEIVE SAFETY MECHANISMS
    // ==============================================

    /**
     * @notice Rejects direct ETH transfers without data
     * @dev Prevents accidental ETH transfers to contract
     */
    receive() external payable {
        revert("No direct ETH");
    }

    /**
     * @notice Rejects calls to undefined functions or direct ETH with data
     * @dev Prevents accidental ETH transfers or invalid function calls
     */
    fallback() external payable {
        revert("Invalid call");
    }
}
