const { assert } = require("chai");
const chai = require("chai");

const { expect } = chai;
const { ethers, deployments, getNamedAccounts, waffle } = require("hardhat");

chai.use(waffle.solidity);

describe("Deme", function () {
  it("Single cheque: send and claim", async function () {
    const { deployer, tester } = await getNamedAccounts();
    await deployments.fixture(['Deme']);

    const aliceToken = await deployments.get('AliceToken');
    const demeDeployment = await deployments.get('Deme');

    await deployments.read('AliceToken', 'balanceOf', deployer);

    await deployments.execute('AliceToken', {from: deployer, log: true}, 'approve', demeDeployment.address, 1000);

    const Deme = await ethers.getContractFactory("Deme");

    const deme = await Deme.attach(demeDeployment.address);

    const block = await ethers.provider.getBlock()

    await deme.setupCheque({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      dates: [block.timestamp],
    });

    const claimable = await deme.claimableCheques(tester)
    expect(claimable.length).to.equal(1);
    console.log('claimable', claimable)
    console.error(claimable)
    const cheque = await deme.cheques(claimable[0])
    console.log(cheque)
    console.log(tester)
    await deployments.execute('Deme', {from: tester, log: true}, 'claimCheques', claimable);

    const balance = await deployments.read('AliceToken', 'balanceOf', tester);
    expect(balance).to.equal(1000);
  })

  it("Single cheque: send and claim", async function () {
    const { deployer, tester } = await getNamedAccounts();
    await deployments.fixture(['Deme']);

    const aliceToken = await deployments.get('AliceToken');
    const demeDeployment = await deployments.get('Deme');

    await deployments.read('AliceToken', 'balanceOf', deployer);

    await deployments.execute('AliceToken', {from: deployer, log: true}, 'approve', demeDeployment.address, 1000);

    const Deme = await ethers.getContractFactory("Deme");

    const deme = await Deme.attach(demeDeployment.address);

    const block = await ethers.provider.getBlock()

    await deme.setupCheque({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      dates: [block.timestamp, block.timestamp + 1000],
    });

    const claimable = await deme.claimableCheques(tester)
    expect(claimable.length).to.equal(1);
    console.log('claimable', claimable)
    console.error(claimable)
    const cheque = await deme.cheques(claimable[0])
    console.log(cheque)
    console.log(tester)
    await deployments.execute('Deme', {from: tester, log: true}, 'claimCheques', claimable);

    const balance = await deployments.read('AliceToken', 'balanceOf', tester);
    expect(balance).to.equal(1000);
  })


  it("Multiple cheque: send and claim multiple", async function () {
    const { deployer, tester } = await getNamedAccounts();
    await deployments.fixture(['Deme']);

    const aliceToken = await deployments.get('AliceToken');
    const demeDeployment = await deployments.get('Deme');

    await deployments.read('AliceToken', 'balanceOf', deployer);

    await deployments.execute('AliceToken', {from: deployer, log: true}, 'approve', demeDeployment.address, 3000);

    const Deme = await ethers.getContractFactory("Deme");

    const deme = await Deme.attach(demeDeployment.address);

    const block = await ethers.provider.getBlock()

    await deme.setupCheque({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      dates: [block.timestamp, block.timestamp, block.timestamp],
    });

    const claimable = await deme.claimableCheques(tester)
    expect(claimable.length).to.equal(3);
    const cheque = await deme.cheques(claimable[0])
    await deployments.execute('Deme', {from: tester, log: true}, 'claimCheques', claimable);

    const balance = await deployments.read('AliceToken', 'balanceOf', tester);
    expect(balance).to.equal(3000);
  })

  it("Once cheque: send and make nothing", async function () {
    const { deployer, tester } = await getNamedAccounts();
    await deployments.fixture(['Deme']);

    const aliceToken = await deployments.get('AliceToken');
    const demeDeployment = await deployments.get('Deme');

    await deployments.read('AliceToken', 'balanceOf', deployer);

    await deployments.execute('AliceToken', {from: deployer, log: true}, 'approve', demeDeployment.address, 1000);

    const Deme = await ethers.getContractFactory("Deme");

    const deme = await Deme.attach(demeDeployment.address);

    const block = await ethers.provider.getBlock()

    await deme.setupCheque({
      amount: 1001,
      token: aliceToken.address,
      to: tester,
      dates: [block.timestamp, block.timestamp, block.timestamp],
    });

    const claimable = await deme.claimableCheques(tester)
    expect(claimable.length).to.equal(0);
  })

})