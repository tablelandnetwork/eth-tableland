// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {TablelandTables} from "../TablelandTables.sol";
import {TablelandController} from "../TablelandController.sol";
import {Policies} from "../policies/Policies.sol";
import {TablelandPolicy} from "../TablelandPolicy.sol";
import "../policies/ERC721EnumerablePolicies.sol";
import "../policies/ERC721AQueryablePolicies.sol";

contract TestReentrancyRunSQLLegacy is TablelandController, ERC721, Ownable {
    TablelandTables private _tableland;

    constructor(address registry) ERC721("TestCreateFromContract", "MTK") {
        _tableland = TablelandTables(registry);
    }

    function getPolicy(
        address,
        uint256
    ) public payable override returns (TablelandPolicy memory) {
        uint256 tableId = 1;
        // TODO: remove this test, this function is depeciated
        _tableland.runSQL(
            msg.sender,
            tableId,
            "delete * from msgsendertableidontown"
        );
        // Return allow-all policy
        return
            TablelandPolicy({
                allowAlter: true,
                allowInsert: true,
                allowUpdate: true,
                allowDelete: true,
                whereClause: Policies.joinClauses(new string[](0)),
                withCheck: Policies.joinClauses(new string[](0)),
                updatableColumns: new string[](0)
            });
    }
}
