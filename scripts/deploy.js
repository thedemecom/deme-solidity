const hre = require("hardhat");


async function main() {
    // We get the contract to deploy
    const Deme = await hre.ethers.getContractFactory("Deme");
    const deme = await Deme.deploy();

    await deme.deployed();

    console.log("Deme deployed to:", deme.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });