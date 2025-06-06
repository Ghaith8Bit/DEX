// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRouter {
    address public WETH;
    IERC20 public token;

    constructor(address _weth, address _token) {
        WETH = _weth;
        token = IERC20(_token);
    }

    function swapExactTokensForETH(uint256 amountIn, uint256, address[] calldata, address to, uint256)
        external
        returns (uint256[] memory amounts)
    {
        token.transferFrom(msg.sender, address(this), amountIn);
        (bool sent,) = to.call{value: amountIn}("");
        require(sent, "send failed");
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }

    function swapExactETHForTokens(uint256, address[] calldata, address to, uint256)
        external
        payable
        returns (uint256[] memory amounts)
    {
        uint256 amountOut = msg.value + (msg.value / 10); // send back 10% more
        token.transfer(to, amountOut);
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = amountOut;
    }
}