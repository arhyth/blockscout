defmodule BlockScoutWeb.BlockListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.Block

  def visit_page(session) do
    visit(session, "/blocks")
  end

  def visit_reorgs_page(session) do
    visit(session, "/reorgs")
  end

  def visit_uncles_page(session) do
    visit(session, "/uncles")
  end

  def block(%Block{number: block_number}) do
    css("[data-test='block_number'][data-block-number='#{block_number}']")
  end

  def blocks(count) do
    css("[data-test='block_number']", count: count)
  end
end
