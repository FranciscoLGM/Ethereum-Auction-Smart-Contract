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
    uint256 public minBidIncrease;

    /// @notice Commission rate percentage taken from refunds
    uint256 public commissionRate;

    /// @notice Time extension applied when bids are placed near end
    uint256 public extensionTime;

    /// @notice Total commission accumulated from refunds
    uint256 public totalCommission;

    /// @notice Flag indicating if auction has been ended
    bool public isAuctionEnded;

    /// @notice Flag indicating if all refunds have been processed
    bool public allRefunded;

    /// @notice Current highest bidder information
    Bidder public highestBidder;

    /// @notice Information about the auction winner and the winning bid
    Bidder public winner;

    /// @notice Mapping of addresses to their pending refund amounts
    mapping(address => uint256) public pendingReturns;

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
    event Refunded(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when the owner withdraws the winning bid amount
     * @param owner Address of the contract owner receiving funds
     * @param amount Amount withdrawn (full winning bid amount)
     */
    event OwnerWithdrawal(address indexed owner, uint256 amount);

    // ==============================================
    //                 MODIFIERS
    // ==============================================

    /// @dev Modifier restricting access to contract owner
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the owner can execute this function."
        );
        _;
    }

    /// @dev Modifier ensuring auction is still active
    modifier onlyActive() {
        require(block.timestamp < endTime, "Auction has ended");
        require(!isAuctionEnded, "Auction has been terminated");
        _;
    }

    /// @dev Modifier ensuring auction has ended
    modifier onlyEnded() {
        require(
            block.timestamp >= endTime || isAuctionEnded,
            "Auction is still active"
        );
        _;
    }

    /// @dev Modifier preventing owner from bidding
    modifier notOwner() {
        require(msg.sender != owner, "Owner cannot place bids");
        _;
    }

    // ==============================================
    //              CONSTRUCTOR
    // ==============================================

    /**
     * @notice Contract constructor initializing auction parameters
     * @dev Sets default auction parameters (7 day duration, 5% min increase, 2% commission)
     */
    constructor() {
        owner = msg.sender;
        endTime = block.timestamp + 7 days;
        minBidIncrease = 105; // 5% minimum increase
        commissionRate = 2; // 2% commission
        extensionTime = 10 minutes;
        isAuctionEnded = false;
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
     */
    function bid() external payable onlyActive notOwner {
        require(msg.value > 0, "Bid must be greater than 0");
        require(
            msg.value >= (highestBidder.amount * minBidIncrease) / 100,
            "Bid must be at least 5% higher than current bid"
        );

        // If there is a previous bid, add it to pending reimbursements
        if (highestBidder.bidderAddress != address(0)) {
            pendingReturns[highestBidder.bidderAddress] += highestBidder.amount;
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
     * @notice Withdraw refundable amounts
     * @dev Emits PartialRefund event based on auction state
     */
    function partialRefund() external onlyActive {
        uint256 refundable = pendingReturns[msg.sender];
        require(refundable > 0, "No refund available");
        pendingReturns[msg.sender] = 0; // Prevent reentrancy

        (bool success, ) = payable(msg.sender).call{value: refundable}("");
        require(success, "Transfer failed");

        emit PartialRefund(msg.sender, refundable);
    }

    /**
     * @notice Ends the auction and declares the winner
     * @dev Allows anyone to finalize the auction after the end time has passed
     * @dev Emits `AuctionEnded` event with winner address and winning amount
     */
    function finalizeAuction() external {
        require(!isAuctionEnded, "Auction already ended");
        require(block.timestamp >= endTime, "Auction has not ended yet");
        _finalizeAuction();
    }

    /**
     * @notice Get remaining auction time
     * @return secondsLeft Remaining time in seconds (0 if ended)
     */
    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= endTime || isAuctionEnded) return 0;
        return endTime - block.timestamp;
    }

    // ==============================================
    //             RESTRICTED FUNCTIONS
    // ==============================================

    /**
     * @notice Refunds all non-winning bidders automatically
     * @dev Only callable by owner after auction ends
     * @dev Processes all bids except the winning one
     * @dev Emits Refunded event for each processed bid
     */
    function refundAll() external onlyOwner onlyEnded {
        require(!allRefunded, "All bids already refunded");

        for (uint256 i = 0; i < allBids.length; i++) {
            if (
                allBids[i].bidderAddress != winner.bidderAddress &&
                pendingReturns[allBids[i].bidderAddress] > 0
            ) {
                uint256 refundable = pendingReturns[allBids[i].bidderAddress];
                require(refundable > 0, "No refund available");
                pendingReturns[allBids[i].bidderAddress] = 0; // Prevent reentrancy
                uint256 commission = (refundable * commissionRate) / 100; // Transfer with 2% commission
                totalCommission += commission;
                uint256 toTransfer = refundable - commission;

                (bool success, ) = payable(allBids[i].bidderAddress).call{
                    value: toTransfer
                }("");
                require(success, "Transfer failed");

                emit Refunded(allBids[i].bidderAddress, toTransfer);
            }
        }
        allRefunded = true;
    }

    /**
     * @notice Withdraws the winning bid amount to the owner
     * @dev Can only be called by the owner after the auction has ended
     * @dev Transfers the full winning bid amount to the contract owner
     */
    function withdrawWinningBid() external onlyOwner onlyEnded {
        require(
            highestBidder.amount > 0 || totalCommission > 0,
            "Already withdrawn"
        );
        uint256 amount = highestBidder.amount + totalCommission;
        highestBidder.amount = 0; // Prevent reentrancy
        totalCommission = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit OwnerWithdrawal(owner, amount);
    }

    // ==============================================
    //              INTERNAL FUNCTIONS
    // ==============================================

    /**
     * @dev Internal function to finalize the auction
     * @dev Sets auction state to ended and records winning bid information
     */
    function _finalizeAuction() private {
        isAuctionEnded = true;
        winner.bidderAddress = highestBidder.bidderAddress;
        winner.amount = highestBidder.amount;
        emit AuctionEnded(winner.bidderAddress, winner.amount);
    }
}
