// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IEscrowManager {
    function lockAsset(address nft, uint256 tokenId) external;
    function releaseAsset(address nft, uint256 tokenId, address to) external;
}

contract BuyNowPayLater is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public paymentToken;
    IERC721 public nft;
    IEscrowManager public escrow;

    // Config
    uint256 public defaultDuration = 30 days;
    address public treasury;
    uint256 public platformFeeBps = 250; // 2.5%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    struct BNPL {
        address buyer;
        address seller;
        uint256 totalPrice;
        uint256 downPayment;
        uint256 paid;
        uint256 deadline;
        uint8 installments; // optional informational field
    }

    mapping(uint256 => BNPL) public plans;

    event BNPLStarted(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 totalPrice, uint256 downPayment);
    event InstallmentPaid(uint256 indexed tokenId, uint256 amount, uint256 totalPaid);
    event BNPLCompleted(uint256 indexed tokenId, address indexed buyer, uint256 totalPaid);
    event BNPLDefaulted(uint256 indexed tokenId, uint256 paidSoFar, bool fundsSentToSeller);

    constructor(address _nft, address _token, address _escrow) {
        nft = IERC721(_nft);
        paymentToken = IERC20(_token);
        escrow = IEscrowManager(_escrow);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero address");
        treasury = _treasury;
    }

    function setPlatformFeeBps(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Max 10%");
        platformFeeBps = bps;
    }

    function setDefaultDuration(uint256 duration) external onlyOwner {
        require(duration > 0, "Invalid duration");
        defaultDuration = duration;
    }

    function startBNPL(uint256 tokenId, uint256 totalPrice, uint256 downPayment) external nonReentrant {
        require(totalPrice > 0 && downPayment > 0, "Invalid terms");
        require(downPayment <= totalPrice, "Down > total");

        address seller = nft.ownerOf(tokenId);
        require(seller != msg.sender, "Buyer cannot be seller");

        // Move NFT to escrow (requires approval by seller for this contract)
        nft.transferFrom(seller, address(escrow), tokenId);
        escrow.lockAsset(address(nft), tokenId);

        // Collect down payment from buyer
        paymentToken.safeTransferFrom(msg.sender, address(this), downPayment);

        plans[tokenId] = BNPL({
            buyer: msg.sender,
            seller: seller,
            totalPrice: totalPrice,
            downPayment: downPayment,
            paid: downPayment,
            deadline: block.timestamp + defaultDuration,
            installments: 0
        });

        emit BNPLStarted(tokenId, msg.sender, seller, totalPrice, downPayment);
    }

    function payInstallment(uint256 tokenId, uint256 amount) external nonReentrant {
        BNPL storage plan = plans[tokenId];
        require(plan.buyer == msg.sender, "Not buyer");
        require(block.timestamp <= plan.deadline, "Deadline passed");
        require(plan.paid + amount <= plan.totalPrice, "Overpay");

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        plan.paid += amount;

        emit InstallmentPaid(tokenId, amount, plan.paid);

        if (plan.paid == plan.totalPrice) {
            // Payout seller and fee to treasury
            uint256 feeAmount = (plan.totalPrice * platformFeeBps) / BPS_DENOMINATOR;
            uint256 sellerAmount = plan.totalPrice - feeAmount;
            if (feeAmount > 0 && treasury != address(0)) {
                paymentToken.safeTransfer(treasury, feeAmount);
            }
            paymentToken.safeTransfer(plan.seller, sellerAmount);

            // Release NFT to buyer
            escrow.releaseAsset(address(nft), tokenId, plan.buyer);
            delete plans[tokenId];
            emit BNPLCompleted(tokenId, msg.sender, plan.totalPrice);
        }
    }

    function defaulted(uint256 tokenId) external onlyOwner nonReentrant {
        BNPL storage plan = plans[tokenId];
        require(block.timestamp > plan.deadline, "Still active");

        // Send paid-so-far to seller (Model A)
        bool sent = false;
        if (plan.paid > 0) {
            paymentToken.safeTransfer(plan.seller, plan.paid);
            sent = true;
        }

        // Return NFT to seller
        escrow.releaseAsset(address(nft), tokenId, plan.seller);
        delete plans[tokenId];

        emit BNPLDefaulted(tokenId, plan.paid, sent);
    }

    function getPlan(uint256 tokenId) external view returns (BNPL memory) {
        return plans[tokenId];
    }

    function isDefaulted(uint256 tokenId) external view returns (bool) {
        BNPL memory plan = plans[tokenId];
        return plan.deadline != 0 && block.timestamp > plan.deadline && plan.paid < plan.totalPrice;
    }
}
