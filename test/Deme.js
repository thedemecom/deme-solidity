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

    const nextId = await deme.next_bill_id();

    const tx=  await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });

    console.log(tx)
    let bill = await deme.bills(nextId)
    expect(bill.attempts).to.equal(0)
    await deployments.execute('Deme', {from: tester, log: true}, 'claim', [nextId]);
    bill = await deme.bills(nextId)
    expect(bill.attempts).to.equal(1)
    console.log(bill)
    const nextTs = await deme.nextClaimBill(nextId);
    console.log('next ts', nextTs);

    const balance = await deployments.read('AliceToken', 'balanceOf', tester);
    expect(balance).to.equal(1000);
    await expect(deployments.execute('Deme', {from: tester, log: true}, 'claim', [nextId])).to.be.reverted;
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
    const nextId = await deme.next_bill_id();

    await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });
    await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });
    await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });

    

    await deployments.execute('Deme', {from: tester, log: true}, 'claim', [nextId, nextId + 1, nextId + 2]);

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

    const nextId = await deme.next_bill_id();

    await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });

    const claimable = await deme.couldClaimBill(tester, nextId)
    expect(claimable).to.equal(false);

  })

  it("Once cheque: expired check", async function () {
    const { deployer, tester } = await getNamedAccounts();
    await deployments.fixture(['Deme']);

    const aliceToken = await deployments.get('AliceToken');
    const demeDeployment = await deployments.get('Deme');

    await deployments.read('AliceToken', 'balanceOf', deployer);

    await deployments.execute('AliceToken', {from: deployer, log: true}, 'approve', demeDeployment.address, 10000);

    const Deme = await ethers.getContractFactory("Deme");

    const deme = await Deme.attach(demeDeployment.address);

    const nextId = await deme.next_bill_id();

    await deme.setupBill({
      amount: 1000,
      token: aliceToken.address,
      to: tester,
      time_mode: 0,
    });

    const claimable = await deme.couldClaimBill(tester, nextId)
    expect(claimable).to.equal(false);

  })

})