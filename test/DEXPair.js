const { expect } = require("chai");
const { ethers } = require("hardhat");

function sqrt(value) {
  if (value === 0n) return 0n;
  let z = value;
  let x = value / 2n + 1n;
  while (x < z) {
    z = x;
    x = (value / x + x) / 2n;
  }
  return z;
}

async function deployPairFixture() {
  const [owner] = await ethers.getSigners();

  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const tokenA = await MockERC20.deploy("TokenA", "A");
  const tokenB = await MockERC20.deploy("TokenB", "B");

  await tokenA.mint(owner.address, ethers.parseEther("1000"));
  await tokenB.mint(owner.address, ethers.parseEther("1000"));

  const Factory = await ethers.getContractFactory("DEXFactory");
  const factory = await Factory.deploy();

  await factory.addToken(tokenA.target);
  await factory.addToken(tokenB.target);

  const tx = await factory.createPair(tokenA.target, tokenB.target);
  await tx.wait();
  const [a, b] = tokenA.target.toLowerCase() < tokenB.target.toLowerCase() ? [tokenA.target, tokenB.target] : [tokenB.target, tokenA.target];
  const pairAddress = await factory.getPair(a, b);
  const pair = await ethers.getContractAt("DEXPair", pairAddress);
  const lpAddress = await factory.getLPToken(a, b);
  const lp = await ethers.getContractAt("LPToken", lpAddress);

  await tokenA.approve(pair.target, ethers.MaxUint256);
  await tokenB.approve(pair.target, ethers.MaxUint256);

  return { owner, tokenA, tokenB, pair, lp };
}

describe("DEXPair liquidity", function () {
  it("mints sqrt(amountA * amountB) on first add", async function () {
    const { pair, lp } = await deployPairFixture();

    const amountA = ethers.parseEther("100");
    const amountB = ethers.parseEther("100");

    await pair.addLiquidity(amountA, amountB);

    const expected = amountA * amountB;
    const expectedLiquidity = sqrt(expected);
    expect(await lp.totalSupply()).to.equal(expectedLiquidity);
    expect(await pair.reserveA()).to.equal(amountA);
    expect(await pair.reserveB()).to.equal(amountB);
  });

  it("mints proportional liquidity on subsequent adds", async function () {
    const { pair, lp } = await deployPairFixture();

    const amountA1 = ethers.parseEther("100");
    const amountB1 = ethers.parseEther("100");
    await pair.addLiquidity(amountA1, amountB1);

    const supply1 = await lp.totalSupply();
    const reserveA1 = await pair.reserveA();
    const reserveB1 = await pair.reserveB();

    const amountA2 = ethers.parseEther("50");
    const amountB2 = ethers.parseEther("50");
    await pair.addLiquidity(amountA2, amountB2);

    const expected = ((amountA2 * supply1) / reserveA1) < ((amountB2 * supply1) / reserveB1)
      ? (amountA2 * supply1) / reserveA1
      : (amountB2 * supply1) / reserveB1;
    expect(await lp.totalSupply()).to.equal(supply1 + expected);
  });
});
