const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Finance Module", () => {
  let deployer, borrower, multisig;
  let nft, loan, mfh, escrow;
  const loanAmount = ethers.parseEther("100");

  beforeEach(async () => {
    [deployer, borrower, multisig] = await ethers.getSigners();

    const MFHToken = await ethers.getContractFactory("MFHToken");
    mfh = await MFHToken.deploy();
    await mfh.waitForDeployment();

    const NFTMinting = await ethers.getContractFactory("NFTMinting");
    nft = await NFTMinting.deploy(mfh.target);
    await nft.waitForDeployment();

    // Approve metadata
    await nft.approveMetadata("ipfs://collateral");

    // Deploy EscrowManager
    const EscrowManager = await ethers.getContractFactory("EscrowManager");
    escrow = await EscrowManager.deploy(nft.target, deployer.address);
    await escrow.waitForDeployment();

    const LoanModule = await ethers.getContractFactory("LoanModule");
    loan = await LoanModule.deploy(nft.target, mfh.target, escrow.target);
    await loan.waitForDeployment();

    // Set treasury as deployer and approve loan to pull funds
    await loan.setTreasury(deployer.address);
    await mfh.approve(loan.target, ethers.parseEther("1000000"));

    // Fund borrower and mint NFT for borrower
    await mfh.transfer(borrower.address, ethers.parseEther("1000"));
    await mfh.connect(borrower).approve(nft.target, loanAmount);
    await nft.connect(borrower).mintNFT("ipfs://collateral");
    await nft.connect(borrower).approve(loan.target, 1);

    // Trust LoanModule in escrow and set multisig to LoanModule to enable release during test
    await escrow.setTrusted(loan.target, true);
    await escrow.setMultisig(loan.target);
  });

  it("should repay loan and return NFT", async () => {
    await loan.connect(borrower).requestLoan(1, loanAmount);

    // Borrower receives funds from treasury; approve LoanModule to pull repayments
    await mfh.connect(borrower).approve(loan.target, loanAmount);

    // Repay in 4 equal installments of 25
    const installment = ethers.parseEther("25");
    await loan.connect(borrower).repayLoan(1, installment);
    await loan.connect(borrower).repayLoan(1, installment);
    await loan.connect(borrower).repayLoan(1, installment);
    await loan.connect(borrower).repayLoan(1, installment);

    const owner = await nft.ownerOf(1);
    expect(owner.toLowerCase()).to.equal(borrower.address.toLowerCase());
  });

  it("should reject double loan on same NFT", async () => {
    await loan.connect(borrower).requestLoan(1, loanAmount);
    await expect(loan.connect(borrower).requestLoan(1, loanAmount)).to.be.revertedWith("Loan exists");
  });

  it("should not repay if insufficient funds", async () => {
    // No loan yet
    await expect(loan.connect(borrower).repayLoan(1, ethers.parseEther("25"))).to.be.reverted;
  });

  it("should prevent liquidation before deadline", async () => {
    await loan.connect(borrower).requestLoan(1, loanAmount);
    await expect(loan.connect(deployer).liquidateLoan(1)).to.be.revertedWith("Loan not expired");
  });
});
