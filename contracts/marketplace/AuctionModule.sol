// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AuctionModule is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Auction {
        address seller;
        uint256 minBid;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    IERC721 public nft;
    IERC20 public paymentToken;
    address public treasury;
    uint256 public platformFeeBps; // e.g., 250 = 2.5%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    mapping(uint256 => Auction) public auctions;

    event AuctionStarted(uint256 tokenId, uint256 minBid, uint256 endTime);
    event BidPlaced(uint256 tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 tokenId, address winner, uint256 amount);
    event AuctionCancelled(uint256 tokenId, address seller);

    constructor(address _nft, address _token) {
        nft = IERC721(_nft);
        paymentToken = IERC20(_token);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero treasury");
        treasury = _treasury;
    }

    function setPlatformFee(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Max 10%");
        platformFeeBps = bps;
    }

    function startAuction(uint256 tokenId, uint256 minBid, uint256 duration) external nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(duration >= 1 hours, "Too short");

        nft.transferFrom(msg.sender, address(this), tokenId);
        auctions[tokenId] = Auction({
            seller: msg.sender,
            minBid: minBid,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        emit AuctionStarted(tokenId, minBid, block.timestamp + duration);
    }

    function placeBid(uint256 tokenId, uint256 amount) external nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "Not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(amount > auction.highestBid && amount >= auction.minBid, "Low bid");

        if (auction.highestBid > 0) {
            paymentToken.safeTransfer(auction.highestBidder, auction.highestBid);
        }

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;

        emit BidPlaced(tokenId, msg.sender, amount);
    }

    function finalizeAuction(uint256 tokenId) external nonReentrant {
        Auction memory auction = auctions[tokenId];
        require(auction.active, "Already finalized");
        require(block.timestamp >= auction.endTime, "Too early");

        auctions[tokenId].active = false;

        if (auction.highestBid > 0) {
            nft.transferFrom(address(this), auction.highestBidder, tokenId);
            uint256 fee = (auction.highestBid * platformFeeBps) / BPS_DENOMINATOR;
            uint256 sellerAmount = auction.highestBid - fee;
            if (fee > 0 && treasury != address(0)) {
                paymentToken.safeTransfer(treasury, fee);
            }
            paymentToken.safeTransfer(auction.seller, sellerAmount);
            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            nft.transferFrom(address(this), auction.seller, tokenId);
        }
    }

    function cancelAuction(uint256 tokenId) external onlyOwner nonReentrant {
        Auction memory auction = auctions[tokenId];
        require(auction.active, "Not active");
        auctions[tokenId].active = false;

        // Refund current highest bidder if any
        if (auction.highestBid > 0) {
            paymentToken.safeTransfer(auction.highestBidder, auction.highestBid);
        }

        // Return NFT to seller
        nft.transferFrom(address(this), auction.seller, tokenId);
        emit AuctionCancelled(tokenId, auction.seller);
    }
}
