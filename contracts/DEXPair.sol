// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./LPToken.sol";

contract DEXPair is ReentrancyGuard {
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

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event Swapped(address indexed sender, address indexed inputToken, address indexed outputToken, uint256 amountIn, uint256 amountOut);

    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 totalSupply = lpToken.totalSupply();

        uint256 liquidity;
        if (totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min(
                (amountA * totalSupply) / _reserveA,
                (amountB * totalSupply) / _reserveB
            );
        }

        require(liquidity > 0, "Zero liquidity");

        _updateReserves();
        lpToken.mint(msg.sender, liquidity);
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 lpAmount) external nonReentrant {
        require(lpAmount > 0, "Invalid amount");

        uint256 totalSupply = lpToken.totalSupply();

        uint256 amountA = (IERC20(tokenA).balanceOf(address(this)) * lpAmount) / totalSupply;
        uint256 amountB = (IERC20(tokenB).balanceOf(address(this)) * lpAmount) / totalSupply;

        lpToken.burn(msg.sender, lpAmount);
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        _updateReserves();
        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    function swap(address fromToken, uint256 amountIn) external nonReentrant {
        require(amountIn > 0, "Invalid amount");
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
        emit Swapped(msg.sender, input, output, amountIn, amountOut);
    }
}
