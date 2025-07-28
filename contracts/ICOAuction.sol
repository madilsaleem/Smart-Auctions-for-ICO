// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract ICOAuction {
    address public owner;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public auctionEndTime;
    bool public ended;

    mapping(address => uint256) public lockedBids;
    mapping(address => bool) public hasBid;
    
    // ERC-20 token being sold
    IERC20 public token;
    uint256 public tokensForSale;

    event NewHighestBid(address bidder, uint256 amount);
    event BidRefunded(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event TokensClaimed(address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier auctionActive() {
        require(block.timestamp < auctionEndTime, "Auction ended");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= auctionEndTime, "Auction still active");
        _;
    }

    constructor(
        address _tokenAddress,
        uint256 _tokensForSale,
        uint256 _biddingDuration
    ) {
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        tokensForSale = _tokensForSale;
        auctionEndTime = block.timestamp + _biddingDuration;
    }

    function placeBid() external payable auctionActive {
        require(msg.value > highestBid, "Bid too low");
        require(!hasBid[msg.sender], "Already bid");

        // Lock ETH in escrow
        lockedBids[msg.sender] = msg.value;
        hasBid[msg.sender] = true;

        // Refund previous highest bidder
        if (highestBidder != address(0)) {
            uint256 refundAmount = highestBid;
            payable(highestBidder).transfer(refundAmount);
            emit BidRefunded(highestBidder, refundAmount);
        }

        // Update highest bid
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        emit NewHighestBid(msg.sender, msg.value);
    }

    function withdraw() external auctionEnded {
        require(!ended, "Auction finalized");
        require(hasBid[msg.sender], "No bid to withdraw");
        require(msg.sender != highestBidder, "Winner cannot withdraw");

        uint256 amount = lockedBids[msg.sender];
        lockedBids[msg.sender] = 0;
        hasBid[msg.sender] = false;
        
        payable(msg.sender).transfer(amount);
        emit BidRefunded(msg.sender, amount);
    }

    function endAuction() external onlyOwner auctionEnded {
        require(!ended, "Auction already ended");
        
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    function claimTokens() external auctionEnded {
        require(ended, "Auction not finalized");
        require(msg.sender == highestBidder, "Not auction winner");

        // Transfer tokens to winner
        uint256 amount = tokensForSale;
        tokensForSale = 0;
        require(token.transfer(highestBidder, amount), "Token transfer failed");
        
        emit TokensClaimed(highestBidder, amount);
    }

    function withdrawProceeds() external onlyOwner auctionEnded {
        require(ended, "Auction not finalized");
        
        uint256 amount = highestBid;
        highestBid = 0;
        payable(owner).transfer(amount);
    }

    // Emergency function to return funds if no bids
    function emergencyWithdraw() external onlyOwner auctionEnded {
        require(highestBidder == address(0), "Bids exist");
        require(token.transfer(owner, tokensForSale), "Token transfer failed");
        tokensForSale = 0;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}