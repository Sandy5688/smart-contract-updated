// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRoyaltyManager {
    function distributeRoyalty(uint256 tokenId, uint256 salePrice, address buyer) external;
}

contract BiddingSystem is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC721 public nft;
    IERC20 public token;
    address public treasury;
    IRoyaltyManager public royaltyManager;
    uint256 public platformFeeBps = 250; // 2.5%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // tokenId => bidder => amount
    mapping(uint256 => mapping(address => uint256)) public bids;
    // track bidders per tokenId to allow refunds on accept
    mapping(uint256 => address[]) private bidderList;

    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event BidAccepted(uint256 indexed tokenId, address indexed seller, address indexed bidder, uint256 amount);
    event BidCancelled(uint256 indexed tokenId, address indexed bidder, uint256 amount);

    constructor(address _nft, address _token) {
        nft = IERC721(_nft);
        token = IERC20(_token);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero treasury");
        treasury = _treasury;
    }

    function setRoyaltyManager(address _rm) external onlyOwner {
        require(_rm != address(0), "Zero address");
        royaltyManager = IRoyaltyManager(_rm);
    }

    function setPlatformFeeBps(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Max 10%");
        platformFeeBps = bps;
    }

    function placeBid(uint256 tokenId, uint256 amount) external nonReentrant {
        require(amount > 0, "Zero bid");
        uint256 existing = bids[tokenId][msg.sender];
        if (existing > 0) {
            // refund previous bid before replacing
            token.safeTransfer(msg.sender, existing);
        } else {
            bidderList[tokenId].push(msg.sender);
        }
        token.safeTransferFrom(msg.sender, address(this), amount);
        bids[tokenId][msg.sender] = amount;

        emit BidPlaced(tokenId, msg.sender, amount);
    }

    function cancelBid(uint256 tokenId) external nonReentrant {
        uint256 amount = bids[tokenId][msg.sender];
        require(amount > 0, "No bid");
        bids[tokenId][msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);
        emit BidCancelled(tokenId, msg.sender, amount);
    }

    function acceptBid(uint256 tokenId, address bidder) external nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        uint256 amount = bids[tokenId][bidder];
        require(amount > 0, "No bid from bidder");

        // Distribute royalty first (buyer is bidder)
        if (address(royaltyManager) != address(0)) {
            royaltyManager.distributeRoyalty(tokenId, amount, bidder);
        }

        // Calculate and send platform fee
        uint256 fee = (amount * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerAmount = amount - fee;
        if (fee > 0 && treasury != address(0)) {
            token.safeTransfer(treasury, fee);
        }
        token.safeTransfer(msg.sender, sellerAmount);

        // Transfer NFT to bidder
        nft.transferFrom(msg.sender, bidder, tokenId);

        // Refund all others and clear bids for tokenId
        address[] memory bidders = bidderList[tokenId];
        for (uint256 i = 0; i < bidders.length; i++) {
            address b = bidders[i];
            if (b == bidder) continue;
            uint256 bal = bids[tokenId][b];
            if (bal > 0) {
                bids[tokenId][b] = 0;
                token.safeTransfer(b, bal);
            }
        }
        delete bidderList[tokenId];
        bids[tokenId][bidder] = 0;

        emit BidAccepted(tokenId, msg.sender, bidder, amount);
    }

    function getBid(uint256 tokenId, address bidder) external view returns (uint256) {
        return bids[tokenId][bidder];
    }
}
