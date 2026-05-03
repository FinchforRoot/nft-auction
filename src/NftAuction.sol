// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract NftAuction is Initializable,UUPSUpgradeable{
    // 拍卖结构
    struct Auction {
        // 卖家
        address seller;
        // NFT合约地址
        address nftContract;
        // address(0) 表示 ETH，其他地址表示 ERC20 代币合约
        address bidToken;
        // NFT的tokenId
        uint256 tokenId;
        // 起拍价,单位美元
        uint256 startPrice;
        // 拍卖开始时间
        uint256 startTime;
        // 持续时间
        uint256 duration;
        // 拍卖当前状态
        Status currentStatus;
        // 最高价格
        uint256 highestBid;
        // 最高出价者
        address highestBidder;
        // 出价代币数量
        uint256 highestBidAmount;
    }

    // 状态
    enum Status {
        Pending, //未开始
        OnGoing, //进行中
        Ended, //已结束
        NoBid, //流拍
        Cancelled //已取消
    }

    // NFT拍卖合集 第一层 key：NFT 合约地址 第二层 key：NFT 的 tokenId 值：拍卖ID（uint256）
    mapping(address => mapping(uint256 => uint256)) public nftToken2AuctionId;
    // 拍卖集合
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖的id
    uint256 public nextAuctionId;
    // 价格预言机地址
    IPriceOracle public priceOracle;
    // 管理员
    address public admin;

    // 创建竞拍
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 startTime,
        uint256 duration
    );
    // 取消竞拍
    event AuctionCancelled(uint256 indexed auctionId);
    // 竞拍结束
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );
    // 出价事件
    event NewHighestBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount
    );

    constructor(address _priceOracle) {
        admin = msg.sender;
        // Initialize the price oracle
        priceOracle = IPriceOracle(_priceOracle);
    }

    // 创建拍卖
    function createAuction(
        address _nftContract, //NFT合约地址
        uint256 _tokenId,   //NFT的tokenId
        uint256 _startPrice,    //起拍价
        uint256 _delayHours,    //拍卖开始前的延迟时间，单位小时 [0-720]
        uint256 _durationHours  //拍卖持续时间，单位小时[0-24]
    ) public {
        // 先检查nft合约地址合法
        require(_nftContract != address(0), "nft address invalid");
        // 起拍价必须大于0
        require(_startPrice > 0, "start price invalid");
        // 业务设置允许推迟拍卖，为0表示立即开始，上限是24小时后开启拍卖
        require(
            _delayHours >= 0 && _delayHours < 24,
            "_delayHours invalid"
        );
        // 拍卖持续时间为1-24小时
        require(
            _durationHours >= 1 && _durationHours <= 24,
            "_durationHours invalid"
        );
        // 校验这个nft是否已经上架
        uint256 existingId = nftToken2AuctionId[nftContract][tokenId];
        // 已上架过的NFT不能再次拍卖
        require(existingId !=0,"NFT already in auction");
        // 校验nft是调用者的
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            "you are not the owner of this nft"
        );
        // 校验该NFT是否已经授权给了本合约
        require(
            IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "not authorized"
        );
        uint256 _startTime = block.timestamp + _delayHours;
        // 创建拍卖
        uint256 auctionId = nextAuctionId++;
        // 转移nft到合约
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            bidToken: address(0),
            tokenId: _tokenId,
            startPrice: _startPrice,
            startTime: _startTime,
            duration: _durationHours,
            currentStatus: Status.Pending,
            highestBid: 0,
            highestBidder: address(0),
            highestBidAmount: 0
        });

        // 记录某个NFT是否处于拍卖中
        nftToken2AuctionId[_nftContract][_tokenId] = auctionId;

        emit AuctionCreated(
            auctionId,
            msg.sender,
            _nftContract,
            _tokenId,
            _startPrice,
            _startTime,
            _durationHours
        );
    }

    

    // 参与竞拍
    /**
    校验拍卖存在

    校验状态为 OnGoing

    校验卖家不能自己出价

    分 ETH / ERC20 校验参数

    计算新出价美元价值

    判断首次还是后续出价，分别比价

    退款给前买家（如果有）

    收新买家的钱

    更新状态（bidToken + highestBidAmount + highestBid + highestBidder）

    发事件
     */
    function placeBid(uint256 _auctionId, uint256 _bidAmount,address _tokenAddress) external payable {
        Auction storage auction = auctions[_auctionId];
        require(auction.seller != address(0), "auction not exist");
        require(auction.currentStatus == Status.OnGoing, "auction not on going");
        require(auction.seller != msg.sender, "seller can not bid");
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) external {
        
    }

    /**
     * @dev 取消拍卖
     * @param _auctionId 拍卖id
     * @notice 只有卖家可以在拍卖未开始前操作
     */
    function cancelAuction(uint256 _auctionId) external {
        // 验证拍卖ID有效
        require(_auctionId >0 && _auctionId < nextAuctionId,"Invalid auction ID");
        Auction storage auction = auctions[_auctionId];
        // 验证拍卖存在（通过检查seller不为零地址）
        require(auction.seller != address(0), "Auction not exist");
        // 只有卖家可以取消
        require(msg.sender == auction.seller, "Only seller");
        // 状态必须是Pending
        require(auction.currentStatus == Status.Pending, "Must be Pending");
        // 必须在开始时间之前
        require(block.timestamp < auction.startTime, "Already started");
        // 更新状态
        auction.currentStatus = Status.Cancelled;
        // 退回NFT
        IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        emit AuctionCancelled(_auctionId);
    }
}
