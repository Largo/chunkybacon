# FizzBuzz, the Ruby way
(1..15).map do |n|
  if n % 15 == 0 then "FizzBuzz"
  elsif n % 3 == 0 then "Fizz"
  elsif n % 5 == 0 then "Buzz"
  else n
  end
end
