// SPDX-License-Identifier: MIT



pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract CEAZOR_Token is ERC20, ERC20Burnable, Ownable {

  using SafeMath for uint256;
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;
  mapping (address => bool) public dutyFree; 

  address public ceazor = address(0);

  string constant tokenName = "CEAZOR";
  string constant tokenSymbol = "CEAZOR";
  uint256 _totalSupply = 100000000;

  uint256 public basePercent = 0; //will set to 200 after LGE

  constructor(
  ) public payable ERC20(tokenName, tokenSymbol) {
    _mint(msg.sender, _totalSupply);
  }
  
  function addDutyFree(address _to) public onlyOwner {
        dutyFree[_to] = true;
    } 
  function removeDutyFree(address _to) public onlyOwner {
        dutyFree[_to] = false;
    }
    
  function findTwoPercent(uint256 value) public view returns (uint256)  {
    uint256 twoPercent = value.mul(basePercent).div(10000);
    return twoPercent;
  }
  function transfer(address to, uint256 value) public override returns (bool) {
    // require(value <= _balances[msg.sender], "anon, you don't have enough tokens");
    require(to != address(0), "If you want to burn, use the burn function");
    require(to != address(this), "Don't send your tokens to the contract"); //added this
  if (dutyFree[to]) {
    address owner = _msgSender();
    _transfer(owner, to, tokensToTransfer);
     }else if (basePercent > 0){
            uint256 tokenTax = findTwoPercent(value);
            uint256 tokensToTransfer = value.sub(tokenTax);
            uint256 burnAmt = tokenTax.div(2);
            uint256 toCeazor = tokenTax.sub(burnAmt);
            address owner = _msgSender();
            _transfer(owner, to, tokensToTransfer);
            _burn(owner, burnAmt);
            _transfer(owner, ceazor, toCeazor);  

            emit Transfer(msg.sender, to, tokensToTransfer);
            emit Transfer(msg.sender, address(ceazor), toCeazor);
            emit Transfer(msg.sender, address(0), burnAmt);
            return true;
          }else{
              address owner = _msgSender();
              _transfer(owner, to, value);
              return true;
              }
  }
  function transferFrom(address from, address to, uint256 value) public override returns (bool) {
    require(value <= _balances[from]);
    require(value <= _allowed[from][msg.sender]);
    require(to != address(0), "If you want to burn, use the burn function");
    require(to != address(this), "Don't send your tokens to the contract"); 
      address spender = _msgSender();
      _spendAllowance(from, spender, amount);
      _transfer(from, to, amount);
      return true;
  }
  function seeTaxRate() public view returns(uint256) {
    return basePercent / 100;
  }
  function setTax(uint _basePercent) public onlyOwner {
    require(_basePercent < 201, "Ceazor, don't be greedy!");
    basePercent = _basePercent;
  }
  function setCeazor(address _ceazor) public onlyOwner {
    require(_ceazor != ceazor, "Ceazor is already Ceazor");
    ceazor = _ceazor;
  }
  function inCaseTokensGetStuck(address _token, address to) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(to, amount);
    }
}