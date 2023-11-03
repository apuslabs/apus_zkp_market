// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TaikoData} from "./TaikoData.sol";
import {ApusData} from "./ApusData.sol";
import {IReward, IProver, IProofTask} from "./ApusInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/utils/Address.sol";

interface IERC1271 {
    function isValidSignature(bytes32 _messageHash, bytes memory _signature) external view returns (bytes4 magicValue);
    event SignatureValidation(bytes32 indexed _messageHash, address indexed _signer, bytes4 indexed _magicValue);
}


// 创建一个接口来表示 ERC20 代币合约
interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract ApusTaikoProverPool is IProver, IReward, IERC1271, Ownable {
    using ECDSA for bytes32;

    // using Address for address;
    address[] public pubkeys;
    bytes4 private constant _INTERFACE_ID_ERC1271 = 0x1626ba7e;
    IERC20 public ttkojToken;

    constructor(address _ttkojAddress) Ownable(msg.sender) {
        unchecked {
            ttkojToken = IERC20(_ttkojAddress);
        }
    }

    // 定义一个修饰符，用于检查调用者是否是合约的拥有者
    // modifier onlyOwner {
    //     require(msg.sender == owner, "Caller is not owner");
    //     _;
    // }

    // IProofTask合约地址
    address public proofTaskContract;
    // Apus ERC20合约地址
    address public apusTokenContract;

    function isValidSignature(bytes32 _messageHash, bytes memory _signature) public view override returns (bytes4 magicValue) {
        address signer = _messageHash.recover(_signature);
        for (uint256 i = 0; i < pubkeys.length; i++) {
            if (pubkeys[i] == signer) {
                return _INTERFACE_ID_ERC1271;
            }
        }
        revert("unvalid signature");
    }

    // not safe add ownerable after test
    function addProver(address prover) public {
        pubkeys.push(prover);
    }

    // 设置IProofTask合约地址
    function setProofTaskContract(address _proofTaskContract) external {
        proofTaskContract = _proofTaskContract;
    }

    struct Reward {
        address prover;
        uint64 expiry;
        uint256 amount;
    }
    
    event RewardTransfered(
        uint64 blockId,
        address prover,
        uint256 amount
    );

    // blockID对应的奖励
    mapping(uint64 => Reward) public rewards;

    function convert(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    // 生成ApusData.ProofAssignment的encode的bytes
    function genProofAssignment(address prover, uint256 clientId, uint256 expiry, bytes calldata signature) public pure returns (bytes memory) {
        ApusData.ProofAssignment memory assignment = ApusData.ProofAssignment({
            prover: prover,
            clientId: clientId,
            expiry: expiry,
            signature: signature
        });
        return abi.encode(assignment);
    }

    function onBlockAssigned(
        uint64 blockId,
        TaikoData.BlockMetadataInput calldata input,
        TaikoData.ProverAssignment calldata assignment
    ) external payable {
        // 解析assignment.data -> ProofAssignment
        ApusData.ProofAssignment memory apusAssignment = abi.decode(assignment.data, (ApusData.ProofAssignment));
        // 调用IProofTask的bindTask方法
        IProofTask(proofTaskContract).bindTask(
            ApusData.TaskType.TaikoZKEvm,
            blockId,
            abi.encode(input),
            apusAssignment
        );
        // 记录奖励
        rewards[blockId] = Reward({
            prover: apusAssignment.prover,
            expiry: assignment.expiry,
            amount: msg.value
        });
    }

    function reward(uint64 blockId) external payable onlyOwner {
        // 查询奖励
        Reward memory rewardList = rewards[blockId];
        // 发送奖励
        payable(rewardList.prover).transfer(rewardList.amount);
        // 触发事件
        emit RewardTransfered(blockId, rewardList.prover, rewardList.amount);
    }

    function rewardApusToken(uint256 amount) external onlyOwner {
        // ERC20合约 mint token
        IERC20Mintable(apusTokenContract).mint(address(this), amount);
        // 分配token，待定
    }

    function approveTTKOj(address _spender, uint256 _value) external onlyOwner {
        require(_spender != address(0), "Approve to zero address");
        // 调用ERC20合约的approve方法，注意这里的msg.sender应该有足够的余额
        bool success = ttkojToken.approve(_spender, _value);
        require(success, "Approve failed");
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IProver).interfaceId;
    }
}
