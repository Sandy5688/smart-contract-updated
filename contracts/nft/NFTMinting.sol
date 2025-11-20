// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRoyaltyManager {
    function setRoyalty(uint256 tokenId, address creator, uint256 percent) external;
}

interface IBoostEngine {
    function onMint(address minter, uint256 tokenId) external;
}

contract NFTMinting is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public paymentToken; // MFH token
    uint256 public mintPrice = 10 * 10 ** 18;
    uint256 public maxPerWallet = 5;
    uint256 public defaultRoyaltyBps = 500; // 5%

    mapping(address => uint256) public mintedBy;
    mapping(string => bool) public approvedMetadata;

    IRoyaltyManager public royaltyManager;
    IBoostEngine public boostEngine;

    event NFTMinted(address indexed user, uint256 tokenId);
    event MintPriceUpdated(uint256 newPrice);
    event MaxPerWalletUpdated(uint256 newMax);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event MetadataApproved(string uri);
    event MetadataRevoked(string uri);
    event RoyaltyManagerUpdated(address indexed newManager);
    event BoostEngineUpdated(address indexed newEngine);

    constructor(address _paymentToken) ERC721("MemeNFT", "MEME") {
        require(_paymentToken != address(0), "Zero token");
        paymentToken = _paymentToken;
    }

    function mintNFT(string memory metadataURI) external {
        require(bytes(metadataURI).length > 0, "Invalid metadata URI");
        require(approvedMetadata[metadataURI], "Metadata URI not approved");
        require(mintedBy[msg.sender] < maxPerWallet, "Mint limit exceeded");

        // Collect MFH fee
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), mintPrice);

        _tokenIds.increment();
        uint256 newId = _tokenIds.current();

        _safeMint(msg.sender, newId);
        _setTokenURI(newId, metadataURI);

        mintedBy[msg.sender]++;
        emit NFTMinted(msg.sender, newId);

        // Set default royalty for newly minted token (if manager set)
        if (address(royaltyManager) != address(0) && defaultRoyaltyBps > 0) {
            royaltyManager.setRoyalty(newId, msg.sender, defaultRoyaltyBps);
        }
        // Notify boost engine (if set)
        if (address(boostEngine) != address(0)) {
            boostEngine.onMint(msg.sender, newId);
        }
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit MintPriceUpdated(_price);
    }

    function setMaxPerWallet(uint256 _max) external onlyOwner {
        maxPerWallet = _max;
        emit MaxPerWalletUpdated(_max);
    }

    function withdrawFees(address to) external onlyOwner {
        require(to != address(0), "Zero recipient");
        uint256 balance = IERC20(paymentToken).balanceOf(address(this));
        IERC20(paymentToken).safeTransfer(to, balance);
        emit FeesWithdrawn(to, balance);
    }

    function setRoyaltyManager(address _rm) external onlyOwner {
        royaltyManager = IRoyaltyManager(_rm);
        emit RoyaltyManagerUpdated(_rm);
    }

    function setBoostEngine(address _be) external onlyOwner {
        boostEngine = IBoostEngine(_be);
        emit BoostEngineUpdated(_be);
    }

    function approveMetadata(string calldata uri) external onlyOwner {
        approvedMetadata[uri] = true;
        emit MetadataApproved(uri);
    }

    function revokeMetadata(string calldata uri) external onlyOwner {
        approvedMetadata[uri] = false;
        emit MetadataRevoked(uri);
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }

    function mintedByAddress(address user) external view returns (uint256) {
        return mintedBy[user];
    }
}
