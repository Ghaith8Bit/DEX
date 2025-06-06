// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AITradingPool {
    IERC20 public usdt;
    address public admin;
    IUniswapV2Router02 public uniswapRouter;

    uint256 public totalPoolBalance;
    uint256 public currentTradeId;
    uint256 public feePercent = 5;
    
    // User tracking system
    address[] public userAddresses;
    mapping(address => bool) public isUser;

    struct User {
        uint256 balance;
        uint256 pendingDeposit;
        uint256 pendingWithdraw;
        uint256 lastTradeParticipated;
    }

    mapping(address => User) public users;

    bool public isInTrade;
    uint256 public ethInTrade;

    event Deposited(address indexed user, uint256 amount);
    event WithdrawRequested(address indexed user, uint256 amount);
    event TradeStarted(uint256 tradeId, uint256 amountInUSDT);
    event TradeEnded(uint256 tradeId, uint256 ethBought, uint256 usdtReturned, uint256 profit);
    event ProfitDistributed(uint256 tradeId, address indexed user, uint256 profit);
    event Withdrawn(address indexed user, uint256 amountAfterFee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address _usdt, address _uniswapRouter) {
        usdt = IERC20(_usdt);
        admin = msg.sender;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(usdt.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        
        // Add to user tracking if new
        if (!isUser[msg.sender]) {
            userAddresses.push(msg.sender);
            isUser[msg.sender] = true;
        }

        if (isInTrade) {
            users[msg.sender].pendingDeposit += amount;
        } else {
            users[msg.sender].balance += amount;
            totalPoolBalance += amount;
        }
        emit Deposited(msg.sender, amount);
    }

    function requestWithdraw(uint256 amount) external {
        User storage user = users[msg.sender];
        require(amount <= user.balance, "Insufficient balance");
        
        if (isInTrade) {
            user.pendingWithdraw += amount;
            user.balance -= amount;
            totalPoolBalance -= amount;
        } else {
            user.balance -= amount;
            totalPoolBalance -= amount;
            require(usdt.transfer(msg.sender, amount), "Withdraw failed");
            emit Withdrawn(msg.sender, amount);
        }
        emit WithdrawRequested(msg.sender, amount);
    }

    function startTrade() external onlyAdmin {
        require(!isInTrade, "Already in trade");
        require(totalPoolBalance > 0, "Empty pool");

        isInTrade = true;
        currentTradeId++;

        // Swap USDT to ETH
        uint256 amountIn = totalPoolBalance;
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = uniswapRouter.WETH();

        usdt.approve(address(uniswapRouter), amountIn);
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 15
        );

        ethInTrade = amounts[1];
        emit TradeStarted(currentTradeId, amountIn);
    }

    function endTrade() external onlyAdmin {
        require(isInTrade, "No active trade");

        // Swap ETH back to USDT
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(usdt);

        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{ value: ethInTrade }(
            0,
            path,
            address(this),
            block.timestamp + 15
        );

        uint256 usdtReturned = amounts[1];
        uint256 profit = usdtReturned > totalPoolBalance ? usdtReturned - totalPoolBalance : 0;

        if (profit > 0) {
            uint256 fee = (profit * feePercent) / 100;
            require(usdt.transfer(admin, fee), "Fee transfer failed");
            profit -= fee;
        }

        uint256 base = totalPoolBalance;
        // Distribute profits to active users
        for (uint i = 0; i < userAddresses.length; i++) {
            address userAddr = userAddresses[i];
            User storage u = users[userAddr];
            if (u.balance > 0 && u.lastTradeParticipated < currentTradeId) {
                uint256 share = (u.balance * profit) / base;
                u.balance += share;
                emit ProfitDistributed(currentTradeId, userAddr, share);
            }
        }

        isInTrade = false;
        ethInTrade = 0;
        emit TradeEnded(currentTradeId, amounts[0], usdtReturned, profit);

        // Process pending operations
        for (uint i = 0; i < userAddresses.length; i++) {
            address userAddr = userAddresses[i];
            User storage u = users[userAddr];
            
            // Process deposits
            if (u.pendingDeposit > 0) {
                u.balance += u.pendingDeposit;
                totalPoolBalance += u.pendingDeposit;
                u.pendingDeposit = 0;
            }

            // Process withdrawals
            if (u.pendingWithdraw > 0) {
                uint256 amount = u.pendingWithdraw;
                require(usdt.transfer(userAddr, amount), "Pending withdraw failed");
                u.pendingWithdraw = 0;
                emit Withdrawn(userAddr, amount);
            }

            // Update participation tracking
            u.lastTradeParticipated = currentTradeId;
        }
    }

    receive() external payable {}
}