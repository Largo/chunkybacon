# Snake: Chunky eats bacon. Arrow keys steer, each piece of bacon makes
# Chunky longer. (Paste into a cell and press Run, then click the game.)
show_game(width: 20, height: 15) do |g|
  snake = [[5, 7], [4, 7], [3, 7]]   # the head comes first
  dir = [1, 0]                       # one step to the right
  bacon = [12, 7]
  score = 0

  g.on_key(:left)  { dir = [-1, 0] unless dir == [1, 0] }
  g.on_key(:right) { dir = [1, 0]  unless dir == [-1, 0] }
  g.on_key(:up)    { dir = [0, -1] unless dir == [0, 1] }
  g.on_key(:down)  { dir = [0, 1]  unless dir == [0, -1] }

  g.every(0.15) do
    x, y = snake.first
    head = [x + dir[0], y + dir[1]]

    if !g.inside?(*head) || snake.include?(head)
      g.game_over("Ouch! Chunky ate #{score} bacon.")
      next
    end

    snake.unshift(head)
    if head == bacon
      score += 1
      bacon = g.free_cells.sample
    else
      snake.pop
    end

    g.clear
    g.cell(*bacon, :bacon)
    snake.each { |x, y| g.cell(x, y, :body) }
    g.cell(*head, :chunky)
    g.status("Bacon: #{score}")
  end
end
