// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITablelandTables} from "../interfaces/ITablelandTables.sol";
import {TablelandController} from "../TablelandController.sol";
import {Policies} from "../policies/Policies.sol";
import {TablelandPolicy} from "../TablelandPolicy.sol";

contract TestReentrancyMutateOne is TablelandController, ERC721, Ownable {
    ITablelandTables private _tableland;

    constructor(address registry) ERC721("TestCreateFromContract", "MTK") {
        _tableland = ITablelandTables(registry);
    }

    function getPolicy(
        address,
        uint256
    ) public payable override returns (TablelandPolicy memory) {
        uint256 tableId = 1;
        _tableland.mutate(
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
