// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract NftAuction{
    // 结构
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
        unit256 highestBidAmount;
    }

    enum Status {
        Pending, //未开始
        OnGoing, //进行中
        Ended, //已结束
        Cancelled //已取消
    }

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
        require(_nftContract != address(0), "nft address invalid");
        require(_startPrice > 0, "start price invalid");
        require(
            _delayHours > 0 && _delayHours < 720 hours,
            "_delayHours invalid"
        );
        require(
            _durationHours > 0 && _durationHours < 24 hours,
            "_durationHours invalid"
        );
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
        
        bool isErc20 = false;
        // 校验ETH
        if(_tokenAddress == address(0)){
            require(msg.value > 0 , "bid amount not match with value");
        }else{
            // 校验ERC20
            require(msg.value == 0, "value must be 0 when bid with token");
            require(_tokenAddress.code.length>0,"not a contract");
            try IERC20(_tokenAddress).decimals() returns (uint8){
                isErc20 = true;
            }catch {
                revert("not a valid ERC20 token");
            }
            require(_bidAmount > 0,"_bidAmount is invaild");
        }
        // 如果拍卖行没有人出价
        if(auction.highestBidder == address(0)){
            if(isErc20){
                // 获取出价的美元价值
                uint256 bidUsdValue = priceOracle.getPrice(_tokenAddress, _bidAmount);
                require(bidUsdValue >= auction.startPrice * 105 / 100, "bid amount too low");
                IERC20(_tokenAddress).transferFrom(_tokenAddress, address(this), _bidAmount);
                auction.bidToken = _tokenAddress;
                auction.highestBid = 
            }else{

            }
        }else{

        }
        // 获取出价的美元价值
            uint256 bidUsdValue = priceOracle.getPrice(msg.sender, _bidAmount);
            require(bidUsdValue >= auction.startPrice * 105 / 100, "bid amount too low");
            // 如果有之前的最高出价，退回之前最高出价者的金额【可能是ETH，也可能是ERC20代币】
            if (auction.highestBidder != address(0)) {
                if(auction.bidToken == address(0)){
                    // 之前也是用ETH出价的，直接退回ETH
                    (bool success, ) = auction.highestBidder.call{value: auction.highestBid}("");
                    require(success, "Refund failed");
                }else{
                    // 之前用的ERC20代币出价的，退回ERC20代币
                    IERC20(auction.bidToken).transfer(auction.highestBidder, auction.highestBid);
                }
            }
            // 转移竞拍代币到合约
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _bidAmount);
            // 更新最高出价和最高出价者
            auction.highestBid = bidUsdValue;
            auction.highestBidder = msg.sender;
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) external {
        
    }

    // 取消拍卖
    function cancelAuction(uint256 _auctionId) external {
        
    }
}
