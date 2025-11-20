// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RentalEngine is Ownable, IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC721 public nft;
    address public treasury;
    address public leaseAgreement;
    IERC20 public rewardToken;
    uint256 public defaultReward;

    struct Lease {
        address lessor;
        address lessee;
        uint256 expiresAt;
        bool active;
    }

    mapping(uint256 => Lease) public leases;

    event Rented(uint256 indexed tokenId, address indexed lessor, address indexed lessee, uint256 expiresAt, uint256 reward);
    event Returned(uint256 indexed tokenId, address indexed lessee, bool onTime);
    event Defaulted(uint256 indexed tokenId);
    event LeaseForceEnded(uint256 indexed tokenId, address indexed by);

    constructor(address _nft) {
        nft = IERC721(_nft);
    }

    modifier onlyLeaseAgreement() {
        require(msg.sender == leaseAgreement, "Not LeaseAgreement");
        _;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    function setLeaseAgreement(address _leaseAgreement) external onlyOwner {
        require(_leaseAgreement != address(0), "Invalid lease agreement");
        leaseAgreement = _leaseAgreement;
    }

    function setRewardToken(address _token) external onlyOwner {
        rewardToken = IERC20(_token);
    }

    function setDefaultReward(uint256 _amount) external onlyOwner {
        defaultReward = _amount;
    }

    function registerLease(address lessor, address lessee, uint256 tokenId, uint256 duration) external onlyLeaseAgreement nonReentrant {
        require(!leases[tokenId].active, "Lease already active");
        require(nft.ownerOf(tokenId) == address(this), "NFT not escrowed");
        require(lessor != address(0) && lessee != address(0), "Zero address");
        require(duration > 0, "Invalid duration");

        leases[tokenId] = Lease({
            lessor: lessor,
            lessee: lessee,
            expiresAt: block.timestamp + duration,
            active: true
        });

        emit Rented(tokenId, lessor, lessee, block.timestamp + duration, defaultReward);
    }

    function returnNFT(uint256 tokenId) external nonReentrant {
        Lease memory lease = leases[tokenId];
        require(lease.active, "Not leased");
        require(msg.sender == lease.lessee, "Only lessee can return");
        require(nft.ownerOf(tokenId) == address(this), "NFT not in escrow");

        bool onTime = block.timestamp <= lease.expiresAt;

        // End lease and return NFT to owner
        delete leases[tokenId];
        nft.safeTransferFrom(address(this), lease.lessor, tokenId);

        // Optional reward for on-time return
        if (onTime && address(rewardToken) != address(0) && defaultReward > 0 && treasury != address(0)) {
            // Reward paid from treasury (treasury must approve this contract)
            rewardToken.safeTransferFrom(treasury, lease.lessee, defaultReward);
        }

        emit Returned(tokenId, msg.sender, onTime);
    }

    function markDefaulted(uint256 tokenId) external onlyOwner nonReentrant {
        Lease memory lease = leases[tokenId];
        require(lease.active, "Lease not active");
        require(block.timestamp > lease.expiresAt, "Lease not expired");
        require(nft.ownerOf(tokenId) == address(this), "NFT not in escrow");

        delete leases[tokenId];
        nft.safeTransferFrom(address(this), lease.lessor, tokenId);

        emit Defaulted(tokenId);
    }

    function forceEndLease(uint256 tokenId) external onlyOwner nonReentrant {
        Lease memory lease = leases[tokenId];
        if (lease.active) {
            delete leases[tokenId];
            nft.safeTransferFrom(address(this), lease.lessor, tokenId);
            emit LeaseForceEnded(tokenId, msg.sender);
        }
    }

    function getLeaseInfo(uint256 tokenId) external view returns (Lease memory) {
        return leases[tokenId];
    }

    function isActive(uint256 tokenId) external view returns (bool) {
        return leases[tokenId].active;
    }

    function timeLeft(uint256 tokenId) external view returns (uint256) {
        Lease memory lease = leases[tokenId];
        if (!lease.active || block.timestamp >= lease.expiresAt) return 0;
        return lease.expiresAt - block.timestamp;
    }

    // IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // Rescue functions (admin)
    function rescueERC721(address token, uint256 tokenId, address to) external onlyOwner {
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    function rescueERC20(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}
