# For measuring: a snake that never dies - it goes through the walls and
# ignores itself - 20 steps a second, a whole Snake frame each step.
show_game(width: 20, height: 15) do |g|
  snake = [[5, 7], [4, 7], [3, 7], [2, 7], [1, 7]]
  turn = 0
  g.every(0.05) do
    turn += 1
    x, y = snake.first
    head = turn % 9 == 0 ? [x, (y + 1) % 15] : [(x + 1) % 20, y]
    snake.unshift(head)
    snake.pop
    g.clear
    g.cell(12, 7, :bacon)
    snake.each { |x, y| g.cell(x, y, :body) }
    g.cell(*head, :chunky)
    g.status("Steps: #{turn}")
  end
end
