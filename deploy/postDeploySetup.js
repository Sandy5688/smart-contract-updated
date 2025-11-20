const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const signer = await ethers.getSigner(deployer);
  log(" Running post-deployment setup as:", deployer);

  const getAddress = async (name) => (await get(name)).address;
  const getContract = async (name) =>
    await ethers.getContractAt(name, await getAddress(name), signer);

  // Addresses
  const mfh = await getAddress("MFHToken");
  const vault = await getAddress("TreasuryVault");
  const royalty = await getAddress("RoyaltyManager");
  const escrow = await getContract("EscrowManager");
  const marketplace = await getContract("MarketplaceCore");
  const auction = await getContract("AuctionModule");
  const bidding = await getContract("BiddingSystem");
  const rentalEngine = await getContract("RentalEngine");
  const leaseAgreementAddr = await getAddress("LeaseAgreement");
  const bnpl = await getContract("BuyNowPayLater");
  const loanModule = await getContract("LoanModule");

  // 1. Inject MFHToken
  await (await (await getContract("StakingRewards")).setToken(mfh)).wait();
  await (await (await getContract("RewardDistributor")).setToken(mfh)).wait();
  await (await (await getContract("BoostEngine")).setPaymentToken(mfh)).wait();
  await (await (await getContract("CheckInReward")).setToken(mfh)).wait();
  await (await loanModule.setToken(mfh)).wait();
  log(" MFHToken injected into all modules");

  // 2. Inject TreasuryVault
  await (await (await getContract("BoostEngine")).setTreasury(vault)).wait();
  await (await marketplace.setTreasury(vault)).wait();
  await (await rentalEngine.setTreasury(vault)).wait();
  await (await auction.setTreasury(vault)).wait();
  await (await bidding.setTreasury(vault)).wait();
  await (await loanModule.setTreasury(vault)).wait();
  await (await bnpl.setTreasury(vault)).wait();
  log(" TreasuryVault injected into fee modules");

  // 3. Inject RoyaltyManager
  await (await marketplace.setRoyaltyManager(royalty)).wait();
  await (await bidding.setRoyaltyManager(royalty)).wait();
  log(" RoyaltyManager linked with MarketplaceCore");

  // 4. Whitelist trusted modules in EscrowManager
  const trustedModules = [
    await getAddress("BuyNowPayLater"),
    await getAddress("LoanModule"),
    await getAddress("RentalEngine"),
  ];

  for (const mod of trustedModules) {
    const tx = await escrow.setTrusted(mod, true);
    await tx.wait();
    log(` Whitelisted ${mod} in EscrowManager`);
  }

  log(" EscrowManager whitelisting complete");

  // 5. Wire LeaseAgreement into RentalEngine
  await (await rentalEngine.setLeaseAgreement(leaseAgreementAddr)).wait();
  log(" RentalEngine linked with LeaseAgreement");

  // 6. Defaults for new params
  if (process.env.BNPL_DURATION_DAYS) {
    const days = parseInt(process.env.BNPL_DURATION_DAYS);
    await (await bnpl.setDefaultDuration(days * 24 * 60 * 60)).wait();
  }
  if (process.env.LOAN_INTEREST_BPS) {
    await (await loanModule.setInterestRate(parseInt(process.env.LOAN_INTEREST_BPS))).wait();
  }

  // 7. (Optional) RewardDistributor trigger address
  // const engagementContract = "0x..."; // ← set manually if you have it
  // await (await (await getContract("RewardDistributor")).setTrigger(engagementContract)).wait();
  // log(" Engagement trigger set");

  log(" Post-deploy setup complete.");
};

module.exports.tags = ["PostSetup"];
