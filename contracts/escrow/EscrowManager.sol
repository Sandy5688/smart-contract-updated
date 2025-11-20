// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EscrowManager is Ownable2Step, IERC721Receiver, ReentrancyGuard, Pausable {
    IERC721 public immutable nftContract;
    mapping(address => bool) public trustedModules;
    address public multisig; // ONLY this can release/forfeit

    struct Escrow {
        address depositor;
        uint256 tokenId;
        bool locked;
    }

    mapping(uint256 => Escrow) public escrows;

    event EscrowLocked(address indexed depositor, uint256 indexed tokenId);
    event EscrowReleased(address indexed recipient, uint256 indexed tokenId);
    event EscrowForfeited(address indexed to, uint256 indexed tokenId);
    event TrustedModuleUpdated(address indexed module, bool trusted);
    event MultisigUpdated(address indexed newMultisig);
    event EmergencyWithdraw(address indexed to, uint256 indexed tokenId, address indexed depositor);

    modifier onlyTrusted() {
        require(trustedModules[msg.sender], "Escrow: caller not trusted");
        _;
    }

    modifier onlyMultisig() {
        require(msg.sender == multisig, "Escrow: only multisig");
        _;
    }

    constructor(address _nft, address _multisig) {
        require(_nft != address(0), "Invalid NFT address");
        require(_multisig != address(0), "Invalid multisig");
        nftContract = IERC721(_nft);
        multisig = _multisig;
        emit MultisigUpdated(_multisig);
    }

    function setTrusted(address module, bool trusted) external onlyOwner {
        trustedModules[module] = trusted;
        emit TrustedModuleUpdated(module, trusted);
    }

    function setMultisig(address _multisig) external onlyOwner {
        require(_multisig != address(0), "Invalid multisig");
        multisig = _multisig;
        emit MultisigUpdated(_multisig);
    }

    /// @notice Check if an address is a trusted module
    function isTrusted(address module) external view returns (bool) {
        return trustedModules[module];
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    /**
     * @notice Lock an NFT into escrow. NFT must already be transferred to this contract.
     * @dev Prevents double-lock. The calling contract should transfer NFT before calling this.
     */
    function lockAsset(address nft, uint256 tokenId) external onlyTrusted whenNotPaused nonReentrant {
        require(!escrows[tokenId].locked, "Escrow: already locked");
        require(nft == address(nftContract), "Escrow: invalid NFT contract");
        require(nftContract.ownerOf(tokenId) == address(this), "Escrow: NFT not transferred");
        
        // Mark as locked - NFT should already be in this contract
        escrows[tokenId] = Escrow({
            depositor: msg.sender, // The trusted module calling this
            tokenId: tokenId,
            locked: true
        });

        emit EscrowLocked(msg.sender, tokenId);
    }

    /**
     * @notice Release an NFT from escrow to recipient. Callable ONLY by multisig (2-of-3).
     */
    function releaseAsset(address nft, uint256 tokenId, address recipient) external onlyMultisig whenNotPaused nonReentrant {
        require(escrows[tokenId].locked, "Escrow: not locked");
        require(recipient != address(0), "Escrow: invalid recipient");
        require(nft == address(nftContract), "Escrow: invalid NFT contract");

        // Remove from mapping before external call to avoid reentrancy issues
        delete escrows[tokenId];

        // Transfer NFT from escrow to recipient
        nftContract.safeTransferFrom(address(this), recipient, tokenId);

        emit EscrowReleased(recipient, tokenId);
    }

    /**
     * @notice Forfeit an escrowed NFT to a specified address (treasury/admin).
     * @dev Callable ONLY by multisig.
     */
    function forfeitAsset(address nft, uint256 tokenId, address to) external onlyMultisig whenNotPaused nonReentrant {
        require(escrows[tokenId].locked, "Escrow: not locked");
        require(to != address(0), "Escrow: invalid recipient");
        require(nft == address(nftContract), "Escrow: invalid NFT contract");

        delete escrows[tokenId];

        // Transfer NFT to designated address
        nftContract.safeTransferFrom(address(this), to, tokenId);

        emit EscrowForfeited(to, tokenId);
    }

    function isLocked(uint256 tokenId) external view returns (bool) {
        return escrows[tokenId].locked;
    }

    function getEscrow(uint256 tokenId) external view returns (address depositor, uint256 id, bool locked) {
        Escrow memory e = escrows[tokenId];
        return (e.depositor, e.tokenId, e.locked);
    }

    /**
     * @notice Emergency escape hatch: owner can withdraw an NFT stuck in contract (only when paused).
     * @dev This is for exceptional recovery. NFT is returned to recorded depositor by default.
     */
    function emergencyWithdraw(uint256 tokenId, address to) external onlyOwner whenPaused {
        Escrow memory e = escrows[tokenId];
        address recipient = to == address(0) ? e.depositor : to;
        require(recipient != address(0), "Escrow: bad emergency recipient");
        delete escrows[tokenId];
        nftContract.safeTransferFrom(address(this), recipient, tokenId);
        emit EmergencyWithdraw(recipient, tokenId, e.depositor);
    }

    /**
     * @notice ERC721 receiver handler so safeTransferFrom to this contract succeeds.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        require(msg.sender == address(nftContract), "Escrow: only supported NFT");
        return this.onERC721Received.selector;
    }
}
