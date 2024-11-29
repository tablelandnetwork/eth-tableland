// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ITablelandTables} from "../interfaces/ITablelandTables.sol";
import {TablelandController} from "../TablelandController.sol";
import {Policies} from "../policies/Policies.sol";
import {TablelandPolicy} from "../TablelandPolicy.sol";
import "../policies/ERC721EnumerablePolicies.sol";
import "../policies/ERC721AQueryablePolicies.sol";

contract TestReentrancyMutate is TablelandController, ERC721, Ownable {
    ITablelandTables private _tableland;
    ITablelandTables.Statement[] private statements;

    constructor(address registry) ERC721("TestCreateFromContract", "MTK") {
        _tableland = ITablelandTables(registry);
    }

    function getPolicy(
        address,
        uint256
    ) public payable override returns (TablelandPolicy memory) {
        // try to reenter `mutate` with some kind of malicious call...
        uint256 tableId = 1;
        ITablelandTables.Statement memory statement = ITablelandTables
            .Statement({
                tableId: tableId,
                statement: "delete * from msgsendertableidontown"
            });

        statements.push(statement);

        _tableland.mutate(msg.sender, statements);
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
