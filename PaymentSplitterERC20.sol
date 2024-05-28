// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

    import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract paymentSplitter{

    uint private shareCount = 0;

    address private admin;
    address[] private recievers;

    mapping(IERC20 => uint256) public Toktotal;
    mapping(IERC20 => uint256) public Toksent;
    mapping(address=> uint) private shares;
    mapping (address => mapping (uint => bool)) public sharesPaid;
    mapping (address => bool) public sharesExisting;
    mapping(IERC20 => mapping(address => uint256)) public totalPaid;
    mapping(address => uint) public totalRecieved;

    event SharesAdded(uint share, address indexed Collector);
    event SharesUpdated(uint oldshare,uint256 newShare, address indexed collector);
    event TokPaid(IERC20 indexed token, address indexed collector, uint share);
    event PaymentReset(address indexed collector, uint256 amount);
    event shareRemoved(address indexed collector, uint256 amount);


    constructor(){
        admin = payable(msg.sender);
    }   

    modifier onlyAdmin{
        require(admin == msg.sender, "You are not the admin");
        _;
    }

    modifier enoughShares(uint amount){
        require(amount * 10000/10000 == amount , "the basis points is too small");
        require(amount <= 10000, "The share is more than 100 Percent");
        _;
    }

    modifier notAddresszero(address collector){
        require(collector != address(0), "Not a valid address");
        _;
    }

    modifier hasPayment(address collector){
        require(shares[collector] != 0, "This account has no balance");
        _;
    }

    modifier alreadyFalse(address collector){
        require(sharesPaid[collector][shares[collector]], "The payment has alredy been set to false");
        _;
    }

    modifier alreadyPaid(address collector){
        require(!sharesPaid[collector][shares[collector]],"This address has already been paid, reset to pay again");
        _;
    
    }

    modifier existingShares(address collector){
        require(!sharesExisting[collector],"Adress already has a percentage, Update instead");
        _;
    }


    function tokenAddShare(IERC20 token, address collector, uint256 share) external
    onlyAdmin 
    enoughShares(share) 
    notAddresszero(collector) 
    existingShares(collector){

        shares[collector] = share * token.balanceOf(address(this))/10000;
        recievers.push(collector);
        sharesExisting[collector] = true;

        shareCount++;

        emit SharesAdded(share, collector);

    }


    function getShare(address collector) external view returns(uint){
        return shares[collector];
    }


    function removeShare(address collector) public onlyAdmin{
        uint256 oldshare = shares[collector];
        delete shares[collector];
        emit shareRemoved(collector, oldshare);
    }


    function tokenUpdateShare(IERC20 token, address collector, uint256 share) public onlyAdmin{
        uint oldshare = shares[collector];
        removeShare(collector);

        shares[collector] = share * token.balanceOf(address(this))/10000;

        uint256 newshare = shares[collector];

        emit SharesUpdated(oldshare, newshare, collector);
    }


    function tokenGetBalance(IERC20 token) external view returns(uint){
        return token.balanceOf(address(this));
    }


    function tokenPayment(IERC20 token, address payable collector) external 
    onlyAdmin 
    hasPayment(collector) 
    alreadyPaid(collector){

        require(shares[collector] <= token.balanceOf(address(this)));
        uint256 debit = shares[collector];
        require(token.balanceOf(address(this)) >= debit, "insufficient balance");
     

        SafeERC20.safeTransfer(token, collector, debit);

        totalRecieved[collector]+=debit;
        Toksent[token] +=debit;


        emit TokPaid(token, collector, debit);
    }

    function tokenresetPayment(IERC20 token, address collector, uint amount) external 
    onlyAdmin 
    alreadyFalse(collector){ 

        sharesPaid[collector][shares[collector]] = false;

        tokenUpdateShare(token, collector, amount);
        emit PaymentReset(collector, shares[collector]);
    }
    


}

