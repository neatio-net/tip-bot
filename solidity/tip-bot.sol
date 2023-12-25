// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Tip is ReentrancyGuard{
    address public  owner;
    address public signup_confirmer;
    uint public  neat_balance = 0;
    struct UserHistory{
        uint _receiver;
        uint _sender;
        uint _amount;
        bool _claimed;
        bool _reverted;
    }
    mapping (uint =>UserHistory) public history;
    uint public hist_count;
    struct UserProfile{
        address wallet_address;
        uint[] history;
        uint balance;
    }
    
    mapping(uint => UserProfile) public users;
    uint users_count = 0;

//-----------Events---------
    event SentTip(uint _sender,uint _receiver, uint _amount,bool _claimed);
    event ClaimedPendingTip(uint _sender,uint _receiver, uint _amount,bool _claimed);
    event RevertedPendingTip(uint _sender,uint _receiver, uint _amount,bool _reverted);
    event ProfileAddressSet(address _profile_address,uint _user);
    constructor(address _owner,address _signup_confirmer){
        owner = _owner;
        signup_confirmer = _signup_confirmer;
    }


//--------Modifiers
    modifier isOwner{
        require(msg.sender == owner,"You do not have authority to perform this transaction");
        _;
    }
    modifier isSignUpConfirmer{
        require(msg.sender == signup_confirmer,"You do not have authority to perform this transaction");
        _;
    }
    
    modifier userMustExist(uint userId) {
        require(!isZeroAddress(users[userId].wallet_address), "User must be set up before tip can be claimed");
        _;
    }
//------------Admin setup--------
    function setOwner(address _owner)isOwner public {
        owner = _owner;
    }
    function setSignuConfirmer(address _confirmer)isOwner public {
        signup_confirmer = _confirmer;
    }
//----------Profile------
    function setUpAProfile(address _wallet,uint _user)isSignUpConfirmer public {
        users[_user].wallet_address = _wallet;
        emit ProfileAddressSet(_wallet, _user);
    }
//-------------Transactions----------
    function sendTip(uint receiver, uint amount, uint sender) external payable nonReentrant {
        require(amount <= msg.value, "Sending amount exceeded available balance");
        
        if (!isZeroAddress(users[receiver].wallet_address)) {
            history[hist_count] = UserHistory({
                _receiver: receiver,
                _sender: sender,
                _amount: amount,
                _claimed: true,
                _reverted: false
            });

            hist_count++;
            users[receiver].history.push(hist_count);
            users[sender].history.push(hist_count);
            payable(users[receiver].wallet_address).transfer(amount);
            emit SentTip(sender, receiver, amount, true);
        } else {
            neat_balance += msg.value;
            history[hist_count] = UserHistory({
                _receiver: receiver,
                _sender: sender,
                _amount: amount,
                _claimed: false,
                _reverted: false
            });

            users[receiver].history.push(hist_count);
            users[sender].history.push(hist_count);
            hist_count++;
            emit SentTip(sender, receiver, amount, false);
        }
    }

    function revertTip(uint sender, uint tipIndex) external userMustExist(sender) nonReentrant {
        UserHistory memory hist = history[users[sender].history[tipIndex]];
        require(!hist._claimed, "Tip has been claimed");
        require(!hist._reverted, "Tip has been reverted");

        history[users[sender].history[tipIndex]]._reverted = true;
        payable(users[sender].wallet_address).transfer(hist._amount);
        emit RevertedPendingTip(hist._sender, hist._receiver, hist._amount, true);
    }

    function claimTip(uint receiver, uint tipIndex) external userMustExist(receiver) nonReentrant {
        UserHistory memory hist = history[users[receiver].history[tipIndex]];
        require(!hist._claimed, "Tip has been claimed");
        require(!hist._reverted, "Tip has been reverted");

        history[users[receiver].history[tipIndex]]._claimed = true;
        payable(users[receiver].wallet_address).transfer(hist._amount);
        emit ClaimedPendingTip(hist._sender, hist._receiver, hist._amount, true);
    }

    function withdrawAllTokens(address _token,address _receiver)isOwner public {
        IERC20(_token).transfer(_receiver,IERC20(_token).balanceOf(address(this)));
    }
    function withdrawAllNeatTokens(address _receiver)isOwner public {
        payable (_receiver).transfer(address(this).balance);
    }
    function withdrawSomeNeatTokens(address _receiver,uint _amount)isOwner public {
        payable (_receiver).transfer(_amount);
    }
//-----------Getting all data-----------
    function getAllHistory()view public returns(UserHistory[] memory){
        UserHistory[] memory _history = new UserHistory[](hist_count);
        for (uint i =0; i < hist_count; i++) 
        {
            _history[i] = history[i];
        }
        return _history;
    }
//----------Pure functions---------
    function isZeroAddress(address _address) public pure returns (bool) {
    return _address == address(0);
}
}
