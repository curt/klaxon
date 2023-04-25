defmodule Klaxon.Snippet do
  @tags ~w(p em strong ol ul li)

  def snippify(markdown, max) do
    with {:ok, ast, _} <- EarmarkParser.as_ast(preprocess(markdown)) do
      reduce(ast) |> take(max) |> postprocess()
    end
  end

  defp preprocess(markdown) do
    String.replace(markdown, ~r/\n{2,}/, " \n\n")
  end

  defp postprocess(markdown) do
    String.replace(markdown, ~r/\s+/, " ")
  end

  defp take(list, max) do
    String.trim(
      Enum.reduce_while(list, "", fn x, acc ->
        if String.length(acc) + String.length(x) + 1 <= max do
          {:cont, Enum.join([acc, x])}
        end || {:halt, Enum.join([acc, " ..."])}
      end)
    )
  end

  defp reduce(ast, start \\ [])

  defp reduce(ast, start) when is_list(ast) do
    Enum.reduce(ast, start, fn x, acc ->
      reduce(x, acc)
    end)
  end

  defp reduce(text, acc) when is_binary(text) do
    if String.length(text) > 0 do
      acc ++ [text]
    end || acc
  end

  defp reduce({tag, _attrs, inner, _}, acc) do
    if tag in @tags do
      reduce(inner, acc)
    end || acc
  end
end
