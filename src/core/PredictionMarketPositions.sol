// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PredictionMarketPositions is ERC1155, Ownable, AccessControl {
    // Base URI for token metadata
    string private baseURI;

    constructor(string memory _uri, address _initialOwner) ERC1155(_uri) Ownable(_initialOwner) {
        // Metadata URI for each token
        baseURI = _uri;
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
    // Mint tokens representing shares for a given outcome in a specific market

    function mint(address to, uint256 marketId, uint256 outcomeIndex, uint256 amount) external {
        uint256 tokenId = _getTokenId(marketId, outcomeIndex); // Create unique token ID
        _mint(to, tokenId, amount, "");
        emit TokensMinted(to, tokenId, amount);
    }

    function burn(address from, uint256 marketId, uint256 outcomeIndex, uint256 amount) external {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Burn amount must be greater than zero");
        uint256 tokenId = _getTokenId(marketId, outcomeIndex);
        _burn(from, tokenId, amount);
        emit TokensBurned(from, tokenId, amount);
    }

    function _getTokenId(uint256 marketId, uint256 outcomeIndex) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(marketId, outcomeIndex)));
    }

    // Add a public function to get the token ID
    function getTokenId(uint256 marketId, uint256 outcomeIndex) external pure returns (uint256) {
        return _getTokenId(marketId, outcomeIndex);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
    }

    event TokensMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokensBurned(address indexed from, uint256 indexed tokenId, uint256 amount);
}
