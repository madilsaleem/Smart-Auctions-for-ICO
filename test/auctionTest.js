const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ICOAuction", () => {
  let auction, token;
  let owner, bidder1, bidder2;

  beforeEach(async () => {
    [owner, bidder1, bidder2] = await ethers.getSigners();
    
    const Token = await ethers.getContractFactory("ERC20Mock");
    token = await Token.deploy("Test Token", "TKN", owner.address, 10000);
    
    const Auction = await ethers.getContractFactory("ICOAuction");
    auction = await Auction.deploy(
      token.address,
      1000,
      Math.floor(Date.now()/1000) + 3600 // 1 hour auction
    );
    
    // Transfer tokens to auction contract
    await token.transfer(auction.address, 1000);
  });

  it("should lock ETH when placing bid", async () => {
    await auction.connect(bidder1).placeBid({ value: 100 });
    expect(await auction.lockedBids(bidder1.address)).to.equal(100);
  });

  it("should refund previous highest bidder", async () => {
    await auction.connect(bidder1).placeBid({ value: 100 });
    const balanceBefore = await ethers.provider.getBalance(bidder1.address);
    await auction.connect(bidder2).placeBid({ value: 200 });
    const balanceAfter = await ethers.provider.getBalance(bidder1.address);
    expect(balanceAfter).to.be.gt(balanceBefore);
  });

  it("should transfer tokens to winner", async () => {
    await auction.connect(bidder1).placeBid({ value: 100 });
    // Fast-forward time
    await ethers.provider.send("evm_increaseTime", [3600]);
    await ethers.provider.send("evm_mine");
    await auction.endAuction();
    await auction.connect(bidder1).claimTokens();
    expect(await token.balanceOf(bidder1.address)).to.equal(1000);
  });
});