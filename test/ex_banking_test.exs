defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  setup_all do
    ExBanking.create_user("user1")
    ExBanking.create_user("user2")
    :ok
  end

  describe "create new user" do

    test "Creates new user with correct argument" do
      assert ExBanking.create_user("user3") == :ok
    end

    test "Error user already exists" do
      assert ExBanking.create_user("user1") == {:error, :user_already_exists}
    end

    test "error wrong argument when argument is not string" do
      assert ExBanking.create_user(:user3) == {:error , :wrong_arguments}
    end
  end

  describe "fetch balance of user" do

    test "fetches balance of the user" do
      assert ExBanking.get_balance("user1" , "usd") == {:ok , 0.0}
    end

    test "error when user does not exist" do
      assert ExBanking.get_balance("user4" , "usd") == {:error , :user_does_not_exist}
    end

    test "error when wrong argument given while fetching balance" do
      assert ExBanking.get_balance(:user1 , "usd") == {:error , :wrong_arguments}
    end

    test "error when there is too many requests" do
      ExBanking.create_user("user7")

      error_count =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.get_balance("user7", "usd") end)end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result !== {:error, :too_many_requests_to_user} end)

      assert error_count >= 1
    end
  end

  describe "deposit money" do

    test "deposit money to user succesfully" do
      assert ExBanking.deposit("user1" , 10 , "usd") == {:ok , 10}
    end

    test "Error when incorrect argument is given" do
      assert ExBanking.deposit(:user1 , 10 , "usd") == {:error , :wrong_arguments}
    end

    test "Error when user does not exist" do
      assert ExBanking.deposit("user5" , 10 , "usd") == {:error, :user_does_not_exist}
    end

    test "Error when there are too many request for deposit" do
      ExBanking.create_user("user8")

      error_count =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.deposit("user8", 5, "usd") end)end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result !== {:error, :too_many_requests_to_user} end)

      assert error_count >= 1
    end
  end

  describe "withdraw money from user" do

    test "withdraw money succesfully" do
      ExBanking.deposit("user2" , 10 , "usd")
      assert ExBanking.withdraw("user2" , 5 , "usd") == {:ok , 5}
    end

    test "error when incorrect argument given" do
      assert ExBanking.withdraw("user2" , 1 , :usd) == {:error , :wrong_arguments}
    end

    test "error when withdrawing more money than actual balance" do
      assert ExBanking.withdraw("user2" , 20 ,"usd") == {:error , :not_enough_money}
    end

    test "error when too many request for withdraw" do
      count =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.withdraw("withdraw", 5, "usd") end) end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result !== {:error, :too_many_requests_to_user} end)

      assert count >= 1
    end
  end

  describe "send money from one user to other" do

    test "send money from one user to other successfully" do
      ExBanking.create_user("user10")
      ExBanking.create_user("user11")
      ExBanking.deposit("user10" , 10 , "usd")

      assert ExBanking.send("user10" , "user11" , 5, "usd") == {:ok , 5 , 5}
    end

    test "wrong arguments given" do
      assert ExBanking.send(:user1 , "user2" , 10, "usd") == {:error, :wrong_arguments}
    end

    test "error when sender does not exist" do
      assert ExBanking.send("user12" , "user1" , 10, "usd") == {:error , :sender_does_not_exist}
    end

    test "error when receiver does not exist" do
      assert ExBanking.send("user1" , "user12" , 10, "usd") == {:error , :receiver_does_not_exist}
    end

    test "returns error response when there is too many requests for sender" do
      ExBanking.create_user("user13")
      ExBanking.create_user("user14")

      count =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.send("user13", "user14", 5, "usd") end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result !== {:error, :too_many_requests_to_sender} end)

      assert count >= 1
    end

    test "returns error response when there is too many requests for receiver" do
      ExBanking.create_user("sender")
      ExBanking.create_user("receiver")
      ExBanking.deposit("sender", 1000, "usd")

      count =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.send("sender", "receiver", 5, "usd") end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.count(fn result -> result !== {:error, :too_many_requests_to_receiver} end)

      assert count >= 1
    end
  end

  describe "creating new user starts genServer" do
    test "create user" do
      assert {:ok , _pid} = ExBanking.User.start_link("test")
    end

    test "error when user already in the registry" do
      ExBanking.create_user("test1")
      assert {:error , :user_already_exists} = ExBanking.User.start_link("test1")
    end
  end
end
