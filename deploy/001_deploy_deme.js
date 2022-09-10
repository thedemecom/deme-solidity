
const func = async function (hre) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;

    const {deployer} = await getNamedAccounts();

    await deploy('Deme', {
        from: deployer,
        log: true,
    })
};

func.tags = ['Deme'];
func.dependencies = ['ERC20Tokens']

module.exports = func;