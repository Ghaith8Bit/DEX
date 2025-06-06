// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DEXPair.sol";
import "./LPToken.sol";

contract DEXFactory is Ownable {
    address[] public tokenList;
    address[] public allPairs;

    mapping(address => bool) public isTokenApproved;
    mapping(address => bool) public isTokenBlacklisted;
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => mapping(address => address)) public getLPToken;

    event TokenAdded(address token);
    event TokenBlacklisted(address token, bool status);
    event PairCreated(address indexed tokenA, address indexed tokenB, address pair, address lpToken);

    constructor() Ownable(msg.sender) {}

    // ====================
    // TOKEN MANAGEMENT
    // ====================

    function addToken(address token) external onlyOwner {
        require(!isTokenApproved[token], "Token already approved");
        require(!isTokenBlacklisted[token], "Token is blacklisted");
        require(_isContract(token), "Token must be a contract");

        isTokenApproved[token] = true;
        tokenList.push(token);
        emit TokenAdded(token);
    }

    function blacklistToken(address token, bool status) external onlyOwner {
        isTokenBlacklisted[token] = status;
        emit TokenBlacklisted(token, status);
    }

    function allApprovedTokens() external view returns (address[] memory) {
        return tokenList;
    }

    // ====================
    // PAIR CREATION
    // ====================

    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        require(tokenA != tokenB, "Identical tokens");
        require(isTokenApproved[tokenA] && isTokenApproved[tokenB], "Token(s) not approved");
        require(!isTokenBlacklisted[tokenA] && !isTokenBlacklisted[tokenB], "Token(s) blacklisted");
        require(_isContract(tokenA) && _isContract(tokenB), "Token(s) not contracts");

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        require(getPair[token0][token1] == address(0), "Pair already exists");

        // LP Token
        string memory name = string(abi.encodePacked("LP-", _symbolOf(token0), "-", _symbolOf(token1)));
        string memory symbol = string(abi.encodePacked("LP-", _symbolOf(token0), "-", _symbolOf(token1)));
        LPToken lpToken = new LPToken(name, symbol);

        // Create pair
        DEXPair newPair = new DEXPair(token0, token1, address(lpToken));
        lpToken.transferOwnership(address(newPair));

        getPair[token0][token1] = address(newPair);
        getLPToken[token0][token1] = address(lpToken);
        allPairs.push(address(newPair));

        emit PairCreated(token0, token1, address(newPair), address(lpToken));
        return address(newPair);
    }

    function getAllPairs() external view returns (address[] memory) {
        return allPairs;
    }

    function getPairsForToken(address token) external view returns (address[] memory) {
        uint count;
        for (uint i = 0; i < tokenList.length; i++) {
            (address token0, address token1) = _sortTokens(token, tokenList[i]);
            if (getPair[token0][token1] != address(0)) {
                count++;
            }
        }

        address[] memory pairs = new address[](count);
        uint index = 0;
        for (uint i = 0; i < tokenList.length; i++) {
            (address token0, address token1) = _sortTokens(token, tokenList[i]);
            address pairAddr = getPair[token0][token1];
            if (pairAddr != address(0)) {
                pairs[index++] = pairAddr;
            }
        }

        return pairs;
    }

    // ====================
    // INTERNAL HELPERS
    // ====================

    function _sortTokens(address a, address b) internal pure returns (address, address) {
        return (a < b) ? (a, b) : (b, a);
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

   function _symbolOf(address token) internal view returns (string memory) {
    (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("symbol()"));
    if (success && data.length >= 64) {
        return abi.decode(data, (string));
    }
    return "UNK";
    }
}
