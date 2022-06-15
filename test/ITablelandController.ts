import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import type {
  TablelandTables,
  TestERC721Enumerable,
  TestERC721AQueryable,
  TestTablelandController,
  TestAllowAllTablelandController,
} from "../typechain-types";

chai.use(chaiAsPromised);
const expect = chai.expect;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe("ITablelandController", function () {
  let accounts: SignerWithAddress[];
  let tables: TablelandTables;
  let foos: TestERC721Enumerable;
  let bars: TestERC721AQueryable;
  let controller: TestTablelandController;
  let allowAllController: TestAllowAllTablelandController;

  beforeEach(async function () {
    accounts = await ethers.getSigners();

    // Deploy tables
    tables = (await (
      await ethers.getContractFactory("TablelandTables")
    ).deploy()) as TablelandTables;
    await tables.deployed();
    await (await tables.initialize("https://foo.xyz/")).wait();

    // Deploy test erc721 contracts
    foos = (await (
      await ethers.getContractFactory("TestERC721Enumerable")
    ).deploy()) as TestERC721Enumerable;
    await foos.deployed();
    bars = (await (
      await ethers.getContractFactory("TestERC721AQueryable")
    ).deploy()) as TestERC721AQueryable;
    await bars.deployed();

    // Deploy test controllers
    controller = (await (
      await ethers.getContractFactory("TestTablelandController")
    ).deploy()) as TestTablelandController;
    await controller.deployed();

    allowAllController = (await (
      await ethers.getContractFactory("TestAllowAllTablelandController")
    ).deploy()) as TestAllowAllTablelandController;
    await allowAllController.deployed();

    // Setup controller
    await (await controller.setFoos(foos.address)).wait();
    await (await controller.setBars(bars.address)).wait();
  });

  it("Should set controller for a table", async function () {
    // Test setting controller fails if table does not exist
    const owner = accounts[4];
    await expect(
      tables
        .connect(owner)
        .setController(owner.address, BigNumber.from(1), accounts[3].address)
    ).to.be.revertedWith("Unauthorized");

    let tx = await tables.createTable(
      owner.address,
      "create table testing (int a);"
    );
    let receipt = await tx.wait();
    const [, createEvent] = receipt.events ?? [];
    const tableId = createEvent.args!.tableId;

    // Test only owner can set controller
    const sender = accounts[5];
    await expect(
      tables
        .connect(sender)
        .setController(owner.address, tableId, accounts[3].address)
    ).to.be.revertedWith("Unauthorized");

    // Test setting controller to an EOA address
    const eoaController = accounts[6];
    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, eoaController.address);
    receipt = await tx.wait();
    let [setControllerEvent] = receipt.events ?? [];
    expect(setControllerEvent.args!.tableId).to.equal(tableId);
    expect(setControllerEvent.args!.controller).to.equal(eoaController.address);

    // Test that runSQL is now locked down to this EOA address
    // (not even owner should be able to run SQL now)
    const runStatement = "insert into testing values (0);";
    await expect(
      tables.connect(owner).runSQL(owner.address, tableId, runStatement)
    ).to.be.revertedWith("Unauthorized");
    tx = await tables
      .connect(eoaController)
      .runSQL(eoaController.address, tableId, runStatement);
    await tx.wait();

    // Test setting controller to a contract address
    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, allowAllController.address);
    receipt = await tx.wait();
    [setControllerEvent] = receipt.events ?? [];
    expect(setControllerEvent.args!.tableId).to.equal(tableId);
    expect(setControllerEvent.args!.controller).to.equal(
      allowAllController.address
    );

    // Test that anyone can run SQL through contract controller
    const caller = accounts[7];
    tx = await tables
      .connect(caller)
      .runSQL(caller.address, tableId, runStatement);
    receipt = await tx.wait();
    const [runEvent] = receipt.events ?? [];
    expect(runEvent.args!.caller).to.equal(caller.address);
    expect(runEvent.args!.isOwner).to.equal(false);
    expect(runEvent.args!.tableId).to.equal(tableId);
    expect(runEvent.args!.statement).to.equal(runStatement);
    expect(runEvent.args!.policy.allowInsert).to.equal(true);
    expect(runEvent.args!.policy.allowUpdate).to.equal(true);
    expect(runEvent.args!.policy.allowDelete).to.equal(true);
    expect(runEvent.args!.policy.whereClause).to.equal("");
    expect(runEvent.args!.policy.withCheck).to.equal("");
    expect(runEvent.args!.policy.updatableColumns.length).to.equal(0);
  });

  it("Should get controller for a table", async function () {
    const owner = accounts[4];
    let tx = await tables.createTable(
      owner.address,
      "create table testing (int a);"
    );
    const receipt = await tx.wait();
    const [, createEvent] = receipt.events ?? [];
    const tableId = createEvent.args!.tableId;

    const eoaController = accounts[6];
    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, eoaController.address);
    await tx.wait();

    expect(await tables.getController(tableId)).to.equal(eoaController.address);
  });

  it("Should unset controller for a table", async function () {
    const owner = accounts[4];
    let tx = await tables.createTable(
      owner.address,
      "create table testing (int a);"
    );
    let receipt = await tx.wait();
    const [, createEvent] = receipt.events ?? [];
    const tableId = createEvent.args!.tableId;

    const eoaController = accounts[6];
    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, eoaController.address);
    await tx.wait();
    expect(await tables.getController(tableId)).to.equal(eoaController.address);

    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, ZERO_ADDRESS);
    receipt = await tx.wait();
    const [setControllerEvent] = receipt.events ?? [];
    expect(setControllerEvent.args!.controller).to.equal(ZERO_ADDRESS);

    expect(await tables.getController(tableId)).to.equal(ZERO_ADDRESS);
  });

  it("Should be able to gate run SQL with controller contract", async function () {
    const owner = accounts[4];
    let tx = await tables.createTable(
      owner.address,
      "create table testing (int a);"
    );
    let receipt = await tx.wait();
    const [, createEvent] = receipt.events ?? [];
    const tableId = createEvent.args!.tableId;
    tx = await tables
      .connect(owner)
      .setController(owner.address, tableId, controller.address);
    await tx.wait();

    // Test that run SQL on table is gated by Foo and Bar ownership
    const runStatement = "insert into testing values (0);";
    const caller = accounts[5];
    await expect(
      tables.connect(caller).runSQL(caller.address, tableId, runStatement)
    ).to.be.revertedWith("Unauthorized");

    // Mint a Foo
    tx = await foos.connect(caller).mint();
    await tx.wait();

    // Still gated (need a Bar too)
    await expect(
      tables.connect(caller).runSQL(caller.address, tableId, runStatement)
    ).to.be.revertedWith("Unauthorized");

    // Mint a Bar
    tx = await bars.connect(caller).mint();
    await tx.wait();

    // Caller should be able to run SQL now
    tx = await tables
      .connect(caller)
      .runSQL(caller.address, tableId, runStatement);
    receipt = await tx.wait();
    let [runEvent] = receipt.events ?? [];
    expect(runEvent.args!.caller).to.equal(caller.address);
    expect(runEvent.args!.isOwner).to.equal(false);
    expect(runEvent.args!.tableId).to.equal(tableId);
    expect(runEvent.args!.statement).to.equal(runStatement);
    expect(runEvent.args!.policy.allowInsert).to.equal(true);
    expect(runEvent.args!.policy.allowUpdate).to.equal(true);
    expect(runEvent.args!.policy.allowDelete).to.equal(false);
    expect(runEvent.args!.policy.whereClause).to.equal(
      "foo_id in (0) and bar_id in (0)"
    );
    expect(runEvent.args!.policy.withCheck).to.equal("baz > 0");
    expect(runEvent.args!.policy.updatableColumns.length).to.equal(1);
    expect(runEvent.args!.policy.updatableColumns).to.include("baz");

    // Mint some more
    tx = await foos.connect(caller).mint();
    await tx.wait();
    tx = await bars.connect(caller).mint();
    await tx.wait();
    tx = await bars.connect(caller).mint();
    await tx.wait();

    // Where clause should reflect all owned tokens
    tx = await tables
      .connect(caller)
      .runSQL(caller.address, tableId, runStatement);
    receipt = await tx.wait();
    [runEvent] = receipt.events ?? [];
    expect(runEvent.args!.caller).to.equal(caller.address);
    expect(runEvent.args!.isOwner).to.equal(false);
    expect(runEvent.args!.tableId).to.equal(tableId);
    expect(runEvent.args!.statement).to.equal(runStatement);
    expect(runEvent.args!.policy.allowInsert).to.equal(true);
    expect(runEvent.args!.policy.allowUpdate).to.equal(true);
    expect(runEvent.args!.policy.allowDelete).to.equal(false);
    expect(runEvent.args!.policy.whereClause).to.equal(
      "foo_id in (0,1) and bar_id in (0,1,2)"
    );
    expect(runEvent.args!.policy.withCheck).to.equal("baz > 0");
    expect(runEvent.args!.policy.updatableColumns.length).to.equal(1);
    expect(runEvent.args!.policy.updatableColumns).to.include("baz");
  });
});
