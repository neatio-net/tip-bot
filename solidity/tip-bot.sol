
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Tip{
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

    receive() external payable { 
        neat_balance+=msg.value;
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
    function send_tip(uint _receiver,uint _amount,uint _sender)external payable{
        require(_amount <= msg.value,"Sending amount exceeded available balance");
        if(!isZeroAddress(users[_receiver].wallet_address)){
         history[hist_count] = UserHistory({_receiver:_receiver,_sender:_sender,_amount:_amount,_claimed:true,_reverted:false});
            hist_count++;
            users[_receiver].history.push(hist_count);
        users[_sender].history.push(hist_count);
            payable (users[_receiver].wallet_address).transfer(_amount);
            emit SentTip(_sender, _receiver, _amount, true);
            return;
        }
        neat_balance+=msg.value;
         history[hist_count] = UserHistory({_receiver:_receiver,_sender:_sender,_amount:_amount,_claimed:false,_reverted:false});
        users[_receiver].history.push(hist_count);
        users[_sender].history.push(hist_count);
        hist_count++;
        emit SentTip(_sender, _receiver, _amount, false);
    }

    function revert_tip(uint _sender,uint _tip_index)public {
        require(!isZeroAddress(users[_sender].wallet_address),"User must be setup before being tip can be claimed");
        UserHistory memory _hist = history[users[_sender].history[_tip_index]];
        require(!_hist._claimed,"Tip been claimed");
        require(!_hist._reverted,"Tip been reverted");
        history[users[_sender].history[_tip_index]]._reverted = true;
        payable (users[_sender].wallet_address).transfer(_hist._amount);
        emit RevertedPendingTip(_hist._sender, _hist._receiver, _hist._amount, true);
    }
    function claim_tip(uint _reciever,uint _tip_index)public {
        require(!isZeroAddress(users[_reciever].wallet_address),"User must be setup before being tip can be claimed");
        UserHistory memory _hist = history[users[_reciever].history[_tip_index]];
        require(!_hist._claimed,"Tip been claimed");
        require(!_hist._reverted,"Tip been reverted");
        history[users[_reciever].history[_tip_index]]._claimed = true;
        payable (users[_reciever].wallet_address).transfer(_hist._amount);
        emit ClaimedPendingTip(_hist._sender, _hist._receiver, _hist._amount, true);
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
