// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
//import "../nft/IRoyaltyManager.sol";

interface IRoyaltyManager {
    function distributeRoyalty(uint256 tokenId, uint256 salePrice, address buyer) external;
}

contract MarketplaceCore is Ownable {
    IERC20 public paymentToken;
    IERC721 public nft;
    address public treasury;
    IRoyaltyManager public royaltyManager;

    uint256 public platformFeeBps = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;
    // Optional fee split (sum should equal platformFeeBps)
    address public treasuryOps;
    address public burnAddress;
    address public rewardsTreasury;
    uint256 public opsFeeBps = 300;
    uint256 public burnFeeBps = 100;
    uint256 public rewardsFeeBps = 100;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _nft, address _paymentToken, address _treasury, address _royaltyManager) {
        nft = IERC721(_nft);
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        royaltyManager = IRoyaltyManager(_royaltyManager);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    function setRoyaltyManager(address _rm) external onlyOwner {
        require(_rm != address(0), "Invalid address");
        royaltyManager = IRoyaltyManager(_rm);
    }

    function setFeeSplit(
        address _ops,
        address _burn,
        address _rewards,
        uint256 _opsBps,
        uint256 _burnBps,
        uint256 _rewardsBps
    ) external onlyOwner {
        require(_opsBps + _burnBps + _rewardsBps == platformFeeBps, "Split must equal platform fee");
        treasuryOps = _ops;
        burnAddress = _burn;
        rewardsTreasury = _rewards;
        opsFeeBps = _opsBps;
        burnFeeBps = _burnBps;
        rewardsFeeBps = _rewardsBps;
    }

    function listNFT(uint256 tokenId, uint256 price) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(price > 0, "Invalid price");

        listings[tokenId] = Listing(msg.sender, price);
        nft.transferFrom(msg.sender, address(this), tokenId);

        emit NFTListed(tokenId, msg.sender, price);
    }

    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.price > 0, "Not listed");

        // Remove listing
        delete listings[tokenId];

        // 5% platform fee from price
        uint256 feeAmount = (listing.price * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerAmount = listing.price - feeAmount;

        // Distribute royalty
        royaltyManager.distributeRoyalty(tokenId, listing.price, msg.sender);

        // Transfer funds
        require(paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount), "Payment failed");
        if (treasuryOps != address(0) || burnAddress != address(0) || rewardsTreasury != address(0)) {
            // Split platform fee
            if (opsFeeBps > 0 && treasuryOps != address(0)) {
                require(paymentToken.transferFrom(msg.sender, treasuryOps, (listing.price * opsFeeBps) / BPS_DENOMINATOR), "Ops fee failed");
            }
            if (burnFeeBps > 0 && burnAddress != address(0)) {
                require(paymentToken.transferFrom(msg.sender, burnAddress, (listing.price * burnFeeBps) / BPS_DENOMINATOR), "Burn fee failed");
            }
            if (rewardsFeeBps > 0 && rewardsTreasury != address(0)) {
                require(paymentToken.transferFrom(msg.sender, rewardsTreasury, (listing.price * rewardsFeeBps) / BPS_DENOMINATOR), "Rewards fee failed");
            }
        } else {
            require(paymentToken.transferFrom(msg.sender, treasury, feeAmount), "Fee transfer failed");
        }

        // Transfer NFT to buyer
        nft.transferFrom(address(this), msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, listing.price);
    }

    function setPlatformFee(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Max 10%");
        platformFeeBps = bps;
    }
}
