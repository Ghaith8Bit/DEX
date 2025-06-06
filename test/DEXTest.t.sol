// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../DEXFactory.sol";
import "../DEXPair.sol";
import "../LPToken.sol";
import "../AITradingPool.sol";
import "./helpers/MockERC20.sol";
import "./helpers/MockRouter.sol";

contract DEXTest is Test {
    DEXFactory factory;
    DEXPair pair;
    LPToken lp;
    MockERC20 tokenA;
    MockERC20 tokenB;

    AITradingPool pool;
    MockERC20 usdt;
    MockRouter router;

    function setUp() public {
        factory = new DEXFactory();

        tokenA = new MockERC20("TokenA", "A");
        tokenB = new MockERC20("TokenB", "B");
        tokenA.mint(address(this), 1000 ether);
        tokenB.mint(address(this), 1000 ether);

        factory.addToken(address(tokenA));
        factory.addToken(address(tokenB));

        address pairAddr = factory.createPair(address(tokenA), address(tokenB));
        pair = DEXPair(pairAddr);
        lp = LPToken(factory.getLPToken(address(tokenA), address(tokenB)));

        tokenA.approve(pairAddr, type(uint256).max);
        tokenB.approve(pairAddr, type(uint256).max);

        // setup AI trading pool
        usdt = new MockERC20("USDT", "USDT");
        usdt.mint(address(this), 1000 ether);
        router = new MockRouter(address(1), address(usdt));
        usdt.mint(address(router), 200 ether);
        vm.deal(address(router), 1000 ether);
        pool = new AITradingPool(address(usdt), address(router));
        usdt.approve(address(pool), type(uint256).max);
    }

    function testTokenWhitelistingAndPairCreation() public {
        assertTrue(factory.isTokenApproved(address(tokenA)));
        assertTrue(factory.isTokenApproved(address(tokenB)));
        assertEq(factory.allPairs(0), address(pair));
        assertEq(address(lp.owner()), address(pair));
    }

    function testAddRemoveLiquidityAndSwap() public {
        pair.addLiquidity(100 ether, 100 ether);
        assertEq(lp.balanceOf(address(this)), 200 ether);

        pair.swap(address(tokenA), 10 ether);
        assertGt(tokenB.balanceOf(address(this)), 1000 ether - 100 ether); // received some tokenB

        pair.removeLiquidity(200 ether);
        assertEq(lp.balanceOf(address(this)), 0);
    }

    function testLPTokenMintBurnAccess() public {
        vm.expectRevert();
        lp.mint(address(this), 1);

        pair.addLiquidity(10 ether, 10 ether);
        uint256 bal = lp.balanceOf(address(this));
        vm.prank(address(pair));
        lp.burn(address(this), bal);
        assertEq(lp.totalSupply(), 0);
    }

    function testAITradingPoolTradeCycle() public {
        pool.deposit(100 ether);
        pool.startTrade();
        assertTrue(pool.isInTrade());
        pool.endTrade();
        assertFalse(pool.isInTrade());
        (uint256 bal,,,) = pool.users(address(this));
        assertGt(bal, 100 ether);
    }
}