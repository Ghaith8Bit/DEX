const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying from:", deployer.address);

  // Deploy LPToken (mock)
  const LPToken = await hre.ethers.getContractFactory("LPToken");
  const lpToken = await LPToken.deploy("LP Token", "LPT");
  await lpToken.deployed();
  console.log("LPToken:", lpToken.address);

  // Deploy DEXFactory
  const DEXFactory = await hre.ethers.getContractFactory("DEXFactory");
  const dexFactory = await DEXFactory.deploy();
  await dexFactory.deployed();
  console.log("DEXFactory:", dexFactory.address);

  // Deploy AITradingPool
  const AITradingPool = await hre.ethers.getContractFactory("AITradingPool");
  const usdt = "0xYourUSDTTokenAddress"; // Replace with testnet/mainnet USDT
  const uniswapRouter = "0xUniswapRouterAddress"; // Replace with correct router
  const aiPool = await AITradingPool.deploy(usdt, uniswapRouter);
  await aiPool.deployed();
  console.log("AITradingPool:", aiPool.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
