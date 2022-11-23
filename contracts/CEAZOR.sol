

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract ERC20Detailed is IERC20 {

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  constructor(string memory name, string memory symbol, uint8 decimals) public {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  function name() public view returns(string memory) {
    return _name;
  }

  function symbol() public view returns(string memory) {
    return _symbol;
  }

  function decimals() public view returns(uint8) {
    return _decimals;
  }
}

contract CEAZOR is ERC20Detailed {

  using SafeMath for uint256;
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  address public ceazor = address(0);

  string constant tokenName = "CEAZOR";
  string constant tokenSymbol = "CEAZOR";
  uint8  constant tokenDecimals = 18;
  uint256 _totalSupply = 1000000;
  uint256 public basePercent = 0; //will set to 200 after LGE

  constructor(
  ) public payable ERC20Detailed(tokenName, tokenSymbol, tokenDecimals) {
    _mint(msg.sender, _totalSupply);
  }

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address owner) public view returns (uint256) {
    return _balances[owner];
  }

  function allowance(address owner, address spender) public view returns (uint256) {
    return _allowed[owner][spender];
  }

  function approve(address spender, uint256 value) public returns (bool) {
    require(spender != address(0));
    _allowed[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }
  
  function multiTransfer(address[] memory receivers, uint256[] memory amounts) public {
    for (uint256 i = 0; i < receivers.length; i++) {
      transfer(receivers[i], amounts[i]);
    }
  }

  function findTwoPercent(uint256 value) public view returns (uint256)  {
    uint256 twoPercent = value.mul(basePercent).div(10000);
    return twoPercent;
  }

  function transfer(address to, uint256 value) public returns (bool) {
    require(value <= _balances[msg.sender], "anon, you don't have enough tokens");
    require(to != address(0), "If you want to burn, use the burn function");
    require(to != address(this), "Don't send your tokens to the contract"); //added this

    uint256 tokenTax = findTwoPercent(value);
    uint256 tokensToTransfer = value.sub(tokenTax);
    uint256 burn = tokenTax.div(2);
    uint256 toCeazor = tokenTax.sub(burn);

    _balances[msg.sender] = _balances[msg.sender].sub(value);
    _balances[to] = _balances[to].add(tokensToTransfer);
    _balances[ceazor] = _balances[ceazor].add(toCeazor);
    _totalSupply = _totalSupply.sub(burn);    

    emit Transfer(msg.sender, to, tokensToTransfer);
    emit Transfer(msg.sender, address(ceazor), toCeazor);
    emit Transfer(msg.sender, address(0), burn);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    require(value <= _balances[from]);
    require(value <= _allowed[from][msg.sender]);
    require(to != address(0), "If you want to burn, use the burn function");
    require(to != address(this), "Don't send your tokens to the contract"); 

    _balances[from] = _balances[from].sub(value);

    uint256 tokenTax = findTwoPercent(value);
    uint256 tokensToTransfer = value.sub(tokenTax);
    uint256 burn = tokenTax.div(2);
    uint256 toCeazor = tokenTax.sub(burn);

    _balances[to] = _balances[to].add(tokensToTransfer);
    _balances[ceazor] = _balances[ceazor].add(toCeazor);
    _totalSupply = _totalSupply.sub(burn);

    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

    emit Transfer(from, to, tokensToTransfer);
    emit Transfer(from, address(ceazor), toCeazor);
    emit Transfer(from, address(0), burn);

    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    require(spender != address(0));
    _allowed[msg.sender][spender] = (_allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    require(spender != address(0));
    _allowed[msg.sender][spender] = (_allowed[msg.sender][spender].sub(subtractedValue));
    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
    return true;
  }

  function _mint(address account, uint256 amount) internal {
    require(amount != 0);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(amount != 0);
    require(amount <= _balances[account]);
    _totalSupply = _totalSupply.sub(amount);
    _balances[account] = _balances[account].sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function burnFrom(address account, uint256 amount) external {
    require(amount <= _allowed[account][msg.sender]);
    _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(amount);
    _burn(account, amount);
  }
  function setTax(uint _basePercent) public onlyOwner {
    require(_basePercent < 201, "Ceazor, don't be greedy!")
    basePercent = _basePercent;
  }
  function setCeazor(address _ceazor) public onlyOwner {
    require(_ceazor != ceazor, "Ceazor is already Ceazor");
    ceazor = _ceazor
  }
}
