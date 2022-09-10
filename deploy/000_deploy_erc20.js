const func = async function (hre) {
    const {deployments, getNamedAccounts, ethers} = hre;
    const {deploy, execute} = deployments;

    const {deployer} = await getNamedAccounts();

    await deploy('AliceToken', {
        from: deployer,
        contract: 'ERC20PresetMinterPauser',
        args: [
            'Alice',
            'ALC',
        ],
        log: true,
    });

    const mintAmount = ethers.utils.parseEther('100000').toString();
    await execute(
        'AliceToken',
        {
            from: deployer,
            log: true
        },
        'mint',
        deployer,
        mintAmount
    );
};

func.tags = ['ERC20Tokens'];

module.exports = func;
