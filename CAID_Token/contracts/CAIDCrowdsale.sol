pragma solidity ^0.4.20;
import "./Oraclize.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

//Abstract Token contract
contract CAIDToken{
  function setCrowdsaleContract (address) public;
  function sendCrowdsaleTokens(address, uint256)  public;
  // function setIcoFinishedTrue () public;
  function endICO () public;

}

//Crowdsale contract
contract CAIDCrowdsale is Ownable, usingOraclize{

  using SafeMath for uint;

  uint decimals = 8;

  // Token contract address
  CAIDToken public token;

  uint public startingExchangePrice = 1165134514779731;
  uint public tokenPrice; //0.03USD

  address public distributionAddress;

  // Constructor
  function CAIDCrowdsale(address _tokenAddress, address _distribution) public payable{
    token = CAIDToken(_tokenAddress);
    owner = msg.sender;

    distributionAddress = _distribution;

    token.setCrowdsaleContract(this);
    
    oraclize_setNetwork(networkID_auto);
    oraclize = OraclizeI(OAR.getAddress());
    
    // tokenPrice = startingExchangePrice*8/100;

    oraclizeBalance = msg.value;
        
    updateFlag = true;
    oraclize_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
  }

  uint public constant MIN_DEPOSIT = 1 ether;

  //PRIVATE PHASE CONSTANTS

  uint public constant PRIVATE_STAGE_START = 1523804400; //April 15 2018 17:00 GMT+2
  uint public constant PRIVATE_STAGE_FINISH = 1523804400 + 10 days;

  uint public privateStagePrice;

  uint public privateStageTokensSold;

  uint public constant PRIVATE_STAGE_MAX_CAP = uint(5000000).mul((uint)(10).pow(decimals)); //5 000 000 CAID


  //END PRIVATE PHASE CONSTANTS

  //PRE ICO CONSTANTS

  
  uint public constant PRE_ICO_START = 1530975600; //July 7 2018 17:00 GMT+2
  uint public constant PRE_ICO_FINISH = 1530975600 + 10 days;

  uint public preIcoPrice;

  uint public preIcoTokensSold;

  uint public constant PRE_ICO_MAX_CAP = uint(15000000).mul((uint)(10).pow(decimals)); //15 000 000 CAID


  //END PRE ICO CONSTANTS

  //ICO CONSTANTS

  uint public ICO_START = 1531818000; // July 17 2018 10:00:00 UTC+1
  uint public ICO_FINISH = 1532901600; //July 29 2018 23:00:00 UTC+1

  uint public icoPrice;

  uint public icoTokensSold;

  uint public ICO_MIN_CAP = startingExchangePrice.mul((uint)(1770000)); // 1 770 000 USD
  uint public ICO_MAX_CAP = startingExchangePrice.mul((uint)(8850000)); // 8 850 000 USD
  // uint public constant ICO_MAX_CAP = 2000000 ether;


  //END ICO CONSTANTS
  uint public tokensSold;
  uint public ethCollected = 0;

  
  function getPhase(uint _time) public view returns(uint8) {
    if(_time == 0){
      _time = now;
    }
    if (PRIVATE_STAGE_START <= _time && _time < PRIVATE_STAGE_FINISH){
      return 1;
    }
    if (PRE_ICO_START <= _time && _time < PRE_ICO_FINISH){
      return 2;
    }
    if (ICO_START <= _time && _time < ICO_FINISH){
      return 3;
    }
    return 0;
  }



  mapping (address => uint) public contributorEthCollected;
  
  mapping (address => bool) public whiteList;

  event addToWhiteListEvent(address _address);
  event removeFromWhiteListEvent(address _address);
  
  
  function addToWhiteList(address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = true;
      emit addToWhiteListEvent(_addresses[i]);
    }
  }

  function removeFromWhiteList (address[] _addresses) public onlyOwner {
    for (uint i = 0; i < _addresses.length; i++){
      whiteList[_addresses[i]] = false;
      emit removeFromWhiteListEvent(_addresses[i]);
    }
  }

  // event OnSuccessBuy (address indexed _address, uint indexed _EthValue, uint indexed _percent, uint _tokenValue);

  function () public payable {
    require (whiteList[msg.sender]);

    require (msg.value >= MIN_DEPOSIT);
    
    require (buy(msg.sender, msg.value, now, 0));
  }

  function buy (address _address, uint _value, uint _time, uint _bonus) internal returns(bool) {
    uint8 currentPhase = getPhase(_time);
    require (currentPhase != 0);

    uint tokensToSend;


    if (currentPhase == 1){
      tokensToSend = _value.mul((uint)(10).pow(decimals))/privateStagePrice;
      tokensToSend = tokensToSend.add(tokensToSend.mul(_bonus)/100);

      if(tokensToSend.add(privateStageTokensSold) <= PRIVATE_STAGE_MAX_CAP){
        privateStageTokensSold = privateStageTokensSold.add(tokensToSend);
        tokensSold = tokensSold.add(tokensToSend);

        distributionAddress.transfer(address(this).balance);
      }else{
        return false;
      }

    }else if(currentPhase == 2){
      tokensToSend = _value.mul((uint)(10).pow(decimals))/preIcoPrice;
      tokensToSend = tokensToSend.add(tokensToSend.mul(_bonus)/100);

      if(tokensToSend.add(preIcoTokensSold) <= PRE_ICO_MAX_CAP){
        preIcoTokensSold = preIcoTokensSold.add(tokensToSend);
        tokensSold = tokensSold.add(tokensToSend);

        distributionAddress.transfer(address(this).balance);
      }else{
        return false;
      }

    }else if(currentPhase == 3){
      uint icoDiscount = getIcoDiscount();

      tokensToSend = _value.mul((uint)(10).pow(decimals))/(icoPrice.sub(icoPrice.mul(icoDiscount)/100));
      tokensToSend = tokensToSend.add(tokensToSend.mul(_bonus)/100);

      if(tokensToSend.add(icoTokensSold) <= ICO_MAX_CAP){
        icoTokensSold = icoTokensSold.add(tokensToSend);
        tokensSold = tokensSold.add(tokensToSend);

        contributorEthCollected[_address] = contributorEthCollected[_address].add(_value);

        if (tokensSold >= ICO_MIN_CAP){
          distributionAddress.transfer(address(this).balance);
        }
      }else{
        return false;
      }
    }
  
    token.sendCrowdsaleTokens(_address, tokensToSend);
    return true;    

  }

  function sendEtherManually (address _address, uint _value, uint _bonus) public onlyOwner {
    require (buy(_address, _value, now, _bonus));
  }

  function getIcoDiscount () public view returns(uint) {
    if(icoTokensSold < uint(10000000).mul(uint(10).pow(decimals))){
      return 15;
    }
    if(icoTokensSold < uint(20000000).mul(uint(10).pow(decimals))){
      return 10;
    }
    if(icoTokensSold < uint(30000000).mul(uint(10).pow(decimals))){
      return 5;
    }
    return 0;
  }
  
  bool public isIcoFinished = false;

  function endICO () public onlyOwner {
    require (now > ICO_FINISH && !isIcoFinished);
    isIcoFinished = true;
    token.endICO;
  }
  

   // ORACLIZE functions

  uint public oraclizeBalance = 0;
  bool public updateFlag = false;
  uint public priceUpdateAt;

  function findTenAmUtc (uint ten) public view returns (uint) {
    for (uint i = 0; i < 300; i++){
      if(ten > now){
        return ten.sub(now);
      }
      ten = ten + 1 days;
    }
    return 0;
  }

  function update() internal {
    oraclize_query(86400,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    //86400 - 1 day
  
    oraclizeBalance = oraclizeBalance.sub(oraclize_getPrice("URL")); //request to oraclize
  }

  function startOraclize (uint _time) public onlyOwner {
    require (_time != 0);
    require (!updateFlag);
    
    updateFlag = true;
    oraclize_query(_time,"URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    oraclizeBalance = oraclizeBalance.sub(oraclize_getPrice("URL"));
  }

  function addEtherForOraclize () public payable {
    oraclizeBalance = oraclizeBalance.add(msg.value);
  }

  function requestOraclizeBalance () public onlyOwner {
    updateFlag = false;
    if (address(this).balance >= oraclizeBalance){
      owner.transfer(oraclizeBalance);
    }else{
      owner.transfer(address(this).balance);
    }
    oraclizeBalance = 0;
  }
  
  function stopOraclize () public onlyOwner {
    updateFlag = false;
  }
    
  function __callback(bytes32, string result, bytes) public {
    require(msg.sender == oraclize_cbAddress());

    uint256 price = 10 ** 23 / parseInt(result, 5);

    require(price > 0);
    // currentExchangePrice = price;
    privateStagePrice = price*8/100;
    preIcoPrice = price*15/100;
    icoPrice = price*24/100;

    priceUpdateAt = block.timestamp;
            
    if(updateFlag){
      update();
    }
  }
  
  //end ORACLIZE functions
}