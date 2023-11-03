// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library ApusData {



    // prover zkEVM client 
    struct ClientConfig {
        address owner;
        uint256 id;
        string url;
        uint256 minFee;
        uint8 maxZkEvmInstance;
        uint8 curInstance;
    }


    struct ProverClient {
        address owner;
        // prover stake to apus
        mapping(address => uint256) stakeAmount;
        // apus lock amount when assigned prover proof task
        mapping(address => uint256) lockAmount;
        ClientConfig[] clients;
    }


    enum TaskType {TaikoZKEvm}
    enum TaskStatus {Assigned, Proving, Proved, Rewarded, Slashed}
    
    struct ProofAssignment {
        address prover; // 证明者地址，用于接收奖励
        uint256 clientId; // 客户端ID
        uint256 expiry; // 承诺证明时间
        bytes signature; // 签名
    }
    
    // proof task info
    struct ProofTask {
        TaskType _type; // 任务提供者，例如taiko
        uint64 blockID; // 假定我们是服务于L2的证明者市场
        bytes meta; // 任务携带的元数据
        ApusData.ProofAssignment assigment; // 任务分配信息
        TaskStatus status; // 状态
        address prover; // 最终证明者
    }
}

