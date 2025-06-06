// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LPToken.sol";

contract DEXPair {
    address public tokenA;
    address public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    address public factory;

    constructor(address _tokenA, address _tokenB, address _lpToken) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        lpToken = LPToken(_lpToken);
        factory = msg.sender;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call");
        _;
    }

    function _updateReserves() internal {
        reserveA = IERC20(tokenA).balanceOf(address(this));
        reserveB = IERC20(tokenB).balanceOf(address(this));
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 liquidity = (amountA + amountB);
        lpToken.mint(msg.sender, liquidity);

        _updateReserves();
    }

    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Invalid amount");

        uint256 totalSupply = lpToken.totalSupply();

        uint256 amountA = (IERC20(tokenA).balanceOf(address(this)) * lpAmount) / totalSupply;
        uint256 amountB = (IERC20(tokenB).balanceOf(address(this)) * lpAmount) / totalSupply;

        lpToken.burn(msg.sender, lpAmount);
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        _updateReserves();
    }

    function swap(address fromToken, uint256 amountIn) external {
        require(fromToken == tokenA || fromToken == tokenB, "Invalid token");

        bool isTokenA = fromToken == tokenA;
        address input = isTokenA ? tokenA : tokenB;
        address output = isTokenA ? tokenB : tokenA;

        IERC20(input).transferFrom(msg.sender, address(this), amountIn);

        // Simple constant product formula (with 0.3% fee)
        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;

        uint256 amountInWithFee = (amountIn * 997) / 1000;
        uint256 amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        IERC20(output).transfer(msg.sender, amountOut);
        _updateReserves();
    }
}
