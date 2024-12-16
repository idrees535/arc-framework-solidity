// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PredictionMarketPositions is ERC1155, Ownable, AccessControl {
    // Base URI for token metadata
    string private baseURI;
    // Define roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(string memory _uri, address _initialOwner) ERC1155(_uri) Ownable(_initialOwner) {
        // Metadata URI for each token
        baseURI = _uri;
        // Grant roles to the initial owner
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(MINTER_ROLE, _initialOwner);
        _grantRole(BURNER_ROLE, _initialOwner);
    }
    // Override supportsInterface to resolve conflict between AccessControl and ERC1155
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
   
    /**
     * @notice Mint tokens for a specific market and outcome.
     * @dev Only accounts with MINTER_ROLE can call this function.
     */

    function mint(address to, uint256 marketId, uint256 outcomeIndex, uint256 amount) external onlyRole(MINTER_ROLE)  {
        uint256 tokenId = _getTokenId(marketId, outcomeIndex); // Create unique token ID
        _mint(to, tokenId, amount, "");
        emit TokensMinted(to, tokenId, amount);
    }

    /**
     * @notice Burn tokens for a specific market and outcome.
     * @dev Only accounts with BURNER_ROLE can call this function.
     */

    function burn(address from, uint256 marketId, uint256 outcomeIndex, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Burn amount must be greater than zero");
        uint256 tokenId = _getTokenId(marketId, outcomeIndex);
        _burn(from, tokenId, amount);
        emit TokensBurned(from, tokenId, amount);
    }
    /**
     * @notice Internal function to compute a unique token ID based on marketId and outcomeIndex.
     */
    function _getTokenId(uint256 marketId, uint256 outcomeIndex) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(marketId, outcomeIndex)));
    }

    /**
     * @notice Public function to get the token ID for a specific market and outcome.
     */

    // Add a public function to get the token ID
    function getTokenId(uint256 marketId, uint256 outcomeIndex) external pure returns (uint256) {
        return _getTokenId(marketId, outcomeIndex);
    }

    /**
     * @notice Override URI function to return metadata URI for a token.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
    }

    event TokensMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokensBurned(address indexed from, uint256 indexed tokenId, uint256 amount);
}
