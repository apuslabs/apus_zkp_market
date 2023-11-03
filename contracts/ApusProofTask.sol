
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Market} from "./market.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { ApusData } from "./ApusData.sol";
import { IProofTask, IReward } from "./ApusInterface.sol";

contract ApusProofTask is IProofTask, Ownable {
    uint256 public taskId;
    mapping(address => bool) public allowedProverList;

    Market apusMarket;

    function addAllowedProverAddress(address account) external onlyOwner {
        allowedProverList[account] = true;
    }

    constructor(address marketAddress) Ownable(msg.sender) {
        apusMarket = Market(marketAddress);
        taskId = 0;
    }

    event TaskBound(
        uint256 taskId,
        ApusData.TaskType provider,
        uint256 blockID,
        bytes meta,
        ApusData.ProofAssignment assignment
    );

    event RewardSent(
        uint256 taskId,
        address prover,
        uint256 amount
    );

    // 保存所有的Task，以任务ID为键
    mapping(uint256 => ApusData.ProofTask) public tasks;

    // 保存各种任务类型的所有任务ID，以提供者和状态为键
    mapping(ApusData.TaskType => uint256[]) public typedTasks;

    // 保存证明者的所有任务ID，以证明者和客户端ID和状态为键
    mapping(address => mapping(uint256 => uint256[])) public proverTasks;

    // 保存blockID对应的任务
    mapping(uint64 => uint256) public blockTasks;

    // 保存task对应的合约地址
    mapping(ApusData.TaskType => address) public taskContracts;

    // 设置task对应的合约地址
    function setTaskContract(
        ApusData.TaskType _type,
        address contractAddr
    ) external {
        taskContracts[_type] = contractAddr;
    }

    // 查询task对应的合约地址
    function getContract(
        ApusData.TaskType _type
    ) external view returns (address) {
        return taskContracts[_type];
    }

    // 查询某个任务
    function getTask(uint256 _taskId) external view returns (ApusData.ProofTask memory) {
        return tasks[_taskId];
    }

    // 查询某个类型的所有的任务
    function getTasksByType(
        ApusData.TaskType _type
    ) external view returns (uint256[] memory) {
        return typedTasks[_type];
    }

    // 查询某个prover所有的任务
    function getTasksByProver(
        address prover,
        uint256 clientId
    ) external view returns (uint256[] memory) {
        return proverTasks[prover][clientId];
    }

    // 查询某个blockID对应的assignment
    function getAssignmentByBlockId(
        uint64 blockId
    ) public view returns (ApusData.ProofAssignment memory) {
        return tasks[blockTasks[blockId]].assigment;
    }

    // 绑定Task
    function bindTask(
        ApusData.TaskType _type,
        uint64 blockId,
        bytes calldata meta,
        ApusData.ProofAssignment calldata assignment
    ) external {
        // 验证签名，本期先不做
        // 存储任务，taskId递增
        taskId++;
        tasks[taskId] = ApusData.ProofTask({
            _type: _type,
            blockID: blockId,
            meta: meta,
            assigment: assignment,
            status: ApusData.TaskStatus.Assigned,
            prover: address(0)
        });
        // 修改typedTasks，proverTasks，blockTasks
        typedTasks[_type].push(taskId);
        proverTasks[assignment.prover][assignment.clientId].push(taskId);
        blockTasks[blockId] = taskId;
        apusMarket.dispatchTaskToClient(assignment.prover, assignment.clientId);
        // 触发事件
        emit TaskBound(taskId, _type, blockId, meta, assignment);
    }

    // 完成Task
    function proveTask(uint256 _taskId) external {
        // 验证taskId
        require(_taskId > 0 && _taskId <= taskId, "Invalid taskId");
        // 查询任务
        ApusData.ProofTask storage task = tasks[_taskId];
        // 验证prover
        require(msg.sender == task.assigment.prover || allowedProverList[msg.sender], "Caller is not the prover or allowed Prover");
        apusMarket.releaseTaskToClient(task.assigment.prover, task.assigment.clientId);
        // 验证任务状态
        require(task.status == ApusData.TaskStatus.Assigned, "Task is not pending or does not exist");
        // 修改task状态为已证明
        task.status = ApusData.TaskStatus.Proved;
        task.prover = msg.sender;
        // 调用reward方法，这里还未考虑如果msg.sender != task.assigment.prover的情况，因为抢证明后的利益分配还不明确
        if (block.timestamp <= task.assigment.expiry) {
            reward(_taskId);
        }
    }

    // 目前这里仅触发奖励，不做转账, 以后可以考虑Apus的奖励从这里发出
    function reward(uint256 _taskId) internal {
        // 查询任务
        ApusData.ProofTask memory task = tasks[_taskId];
        // 查询任务提供者，并获取其合约地址
        ApusData.TaskType _type = task._type;
        address contractAddr = taskContracts[_type];
        // 在此场景下是调用ApusTaikoProverPool的rewardProver方法
        IReward(contractAddr).reward(task.blockID);
    }

}
