// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/**
 * @title Smart Contract Auction
 * @dev Implements an ETH auction system with partial refunds, commission fees, and automatic time extensions
 * @author Francisco López G
 */
contract Auction {
    /// @dev Structure for storing bidder information
    /// @param bidderAddress Address of the bidder
    /// @param amount Amount of the bid
    struct Bidder {
        address bidderAddress;
        uint256 amount;
    }

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
    /// @notice Flag indicating if auction has been ended
    bool public isAuctionEnded;
    /// @notice Current highest bidder information
    Bidder public highestBidder;

    /// @notice Mapping of addresses to their pending refund amounts
    mapping(address => uint256) public pendingReturns;

    /// @notice Array of all bids placed in the auction
    Bidder[] private allBids;

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
     * @notice Emitted when a full refund is processed
     * @param bidder Address receiving refund
     * @param amount Refund amount after commission
     */
    event Refunded(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when a partial refund is processed
     * @param bidder Address receiving refund
     * @param amount Full refund amount (no commission)
     */
    event PartialRefund(address indexed bidder, uint256 amount);

    /**
     * @notice Emitted when the owner withdraws the winning bid amount
     * @param owner Address of the contract owner receiving funds
     * @param amount Amount withdrawn (full winning bid amount)
     */
    event OwnerWithdrawal(address indexed owner, uint256 amount);

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

    /**
     * @notice Places a bid in the auction
     * @dev Bid must be at least 5% higher than current highest bid
     * @dev Extends auction time if bid is placed within last 10 minutes
     * @dev Emits NewBid event on successful bid
     * @dev Automatically finalizes auction if time has expired
     */
    function bid() external payable onlyActive {
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

        // Verify and end the auction if the time is exceeded
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
        return (highestBidder.bidderAddress, highestBidder.amount);
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
     * @dev Applies commission if auction has ended
     * @dev Emits Refunded or PartialRefund event based on auction state
     */
    function withdraw() external {
        uint256 refundable = pendingReturns[msg.sender];
        require(refundable > 0, "No refund available");

        // Prevent reentrancy
        pendingReturns[msg.sender] = 0;

        // Transfer with 2% commission if the auction has ended
        uint256 commission = (refundable * commissionRate) / 100;
        uint256 toTransfer = isAuctionEnded
            ? refundable - commission
            : refundable;

        (bool success, ) = msg.sender.call{value: toTransfer}("");
        require(success, "Transfer failed");

        if (isAuctionEnded) {
            emit Refunded(msg.sender, toTransfer);
        } else {
            emit PartialRefund(msg.sender, toTransfer);
        }
    }

    /**
     * @notice Get remaining auction time
     * @return secondsLeft Remaining time in seconds (0 if ended)
     */
    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }

    /**
     * @dev Internal function to finalize the auction
     * @dev Sets auction state to ended and records winning bid information
     */
    function _finalizeAuction() private {
        require(!isAuctionEnded, "Already finalized");
        isAuctionEnded = true;
        emit AuctionEnded(highestBidder.bidderAddress, highestBidder.amount);
    }

    /**
     * @notice Ends the auction and declares the winner
     * @dev Can only be called by the owner after the auction end time has passed
     * @dev Emits `AuctionEnded` event with winner address and winning amount
     */
    function endAuction() external onlyOwner {
        require(!isAuctionEnded, "Auction already ended");
        _finalizeAuction();
    }

    /**
     * @notice Withdraws the winning bid amount to the owner
     * @dev Can only be called by the owner after the auction has ended
     * @dev Transfers the full winning bid amount to the contract owner
     */
    function withdrawWinningBid() external onlyOwner onlyEnded {
        require(highestBidder.amount > 0, "Already withdrawn");
        uint256 amount = highestBidder.amount;
        highestBidder.amount = 0; // Prevent reentrancy

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit OwnerWithdrawal(owner, amount);
    }
}
