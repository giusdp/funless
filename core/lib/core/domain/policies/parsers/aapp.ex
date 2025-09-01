# Copyright 2023 Giuseppe De Palma, Matteo Trentin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Core.Domain.Policies.Parsers.AAPP do
  @moduledoc """
  Parser for AAPP (Advanced APP) configuration scripts.
  Contains the main parse/1 function and several helper functions.

  When the module is loaded, Data.Configurations.AAPP, Data.Configurations.AAPP.Block and Data.Configurations.AAPP.Tag
  are loaded as well. This prevents errors when using String.to_existing_atom/1 in this module.
  """
  @on_load :load_atoms

  defp load_atoms do
    [Data.Configurations.AAPP, Data.Configurations.AAPP.Block, Data.Configurations.AAPP.Tag]
    |> Enum.each(&Code.ensure_loaded?/1)

    :ok
  end

  @doc """
  Parses a given YAML string and builds the relevant AAPP configuration from it.

  ## Parameters
  - content: a String, containing the AAPP configuration as it was written in YAML.
            Must be valid YAML.

  ## Returns
  - {:ok, aapp} if the string was parsed successfully, and the AAPP configuration was built.
  - {:error, YamlElixir._} if the given content was not valid YAML.
  - {:error, errors} if any error was encountered during the parsing.
              The returned errors are a map, with tag names as keys, and the actual errors as values.
              For each tag, each error can either be a single tuple (if the error was at the tag level),
              or a list of tuples (one for each block where an error was found).
              E.g. %{"t1" => [{:error, _}, {:error, _}], "t2" => {:error, :no_blocks}}

  """
  @spec parse(String.t()) ::
          {:ok, Data.Configurations.AAPP.t()} | {:error, %{String.t() => {:error, any}}}
  def parse(content) do
    with {:ok, yaml} <- YamlElixir.read_from_string(content) do
      yaml |> parse_script()
    end
  end

  @doc """
  Helper function, performs the actual parsing of the YAML file into an AAPP struct.

  ## Parameters
  - yaml: parsed YAML. Should be a list, with each element encoding a single tag.

  ## Returns
  - {:error, :unknown_construct} if the given parsed YAML has an incorrect structure.
  - See returns values for parse/1.
  """
  @spec parse_script([map()]) ::
          {:ok, Data.Configurations.AAPP.t()} | {:error, %{String.t() => {:error, any}}}
  def parse_script([_ | _] = yaml) do
    {parsed, errors} =
      yaml
      |> Enum.map(fn tag -> tag |> Map.to_list() |> parse_tag end)
      |> Enum.split_with(&match?({_, {:ok, _}}, &1))

    case errors do
      [] ->
        {:ok,
         %Data.Configurations.AAPP{
           tags:
             parsed
             |> Enum.map(fn {tag_name, {:ok, tag}} -> {tag_name, tag} end)
             |> Enum.into(%{})
         }}

      [_ | _] ->
        {:error, errors |> Enum.into(%{})}
    end
  end

  def parse_script(_) do
    {:error, :unknown_construct}
  end

  @doc """
  Helper function, parses a single tag and builds the relative AAPP.Tag struct.

  ## Parameters
  - [_, _]: should be a 2-element list, with shape:
            [{tag_name, tag}, {"followup", followup}] or [{"followup", followup}, {tag_name, tag}].
            The order of the two elements can vary, as the list is built from a Map, and the keys
            are in lexicographic order; therefore, two different clauses are given for this function,
            with the same behaviour.

  ## Returns
  - {tag_name, tag} if the tag was parsed successfully, with "tag" being an AAPP.Tag struct.
  - {tag_name, {:error, :no_blocks}} when the given YAML has no blocks associated with the tag.
  - {tag_name, {:error, :unknown_followup}} when the given YAML has a followup value that is neither "default" nor "fail".
  - {tag_name, {:error, :unknown_construct}} when the given YAML is malformed or has additional keys in the tag definition.
  - See returns values for parse/1.
  """
  @spec parse_tag([{String.t(), any}]) ::
          {String.t(),
           {:error, :no_blocks | :unknown_construct | :unknown_followup | [{:error, any}]}
           | {:ok, Data.Configurations.AAPP.Tag.t()}}
  def parse_tag([{"followup", _} = followup, {_, _} = tag]) do
    parse_tag([tag, followup])
  end

  def parse_tag([{tag_name, [_ | _] = blocks}, {"followup", followup}])
      when followup in ["default", "fail"] do
    {parsed, errors} =
      blocks |> Enum.map(&parse_block/1) |> Enum.split_with(&match?({:ok, _}, &1))

    tag_content =
      case errors do
        [] ->
          {:ok,
           %Data.Configurations.AAPP.Tag{
             blocks:
               parsed
               |> Enum.map(fn {:ok, block} -> block end),
             followup: String.to_existing_atom(followup)
           }}

        [_ | _] ->
          {:error, errors}
      end

    {tag_name, tag_content}
  end

  def parse_tag([{_tag_name, _blocks = [_ | _]} = tag]) do
    parse_tag([tag, {"followup", "fail"}])
  end

  def parse_tag([{tag_name, _blocks = [_ | _]}, {"followup", _}]) do
    {tag_name, {:error, :unknown_followup}}
  end

  def parse_tag([{tag_name, []} | _]) do
    {tag_name, {:error, :no_blocks}}
  end

  def parse_tag([{tag_name, nil} | _]) do
    {tag_name, {:error, :no_blocks}}
  end

  def parse_tag([{tag_name, _} | _]) do
    {tag_name, {:error, :unknown_construct}}
  end

  @doc """
  Helper function, parses a single block and builds the relative AAPP.Block struct.

  ## Parameters
  - block: a map, with a mandatory "workers" key.
           Can also have a "strategy" key with either "random", "best-first", or "platform" value.
           Can have an "affinity" key with a list of strings (simplified compared to APP format).
           If the "strategy" key is missing, "best-first" is assumed as value.
           Other missing fields are filled when building the struct.

  ## Returns
  - {:ok, block} if the block was parsed successfully, with "block" being an AAPP.Block struct.
  - {:error, :no_block_workers} if the "workers" key was missing in the given block.
  - See returns values for parse/1.
  """
  @spec parse_block(%{String.t() => any}) ::
          {:ok, Data.Configurations.AAPP.Block.t()} | {:error, :no_block_workers}
  def parse_block(%{"workers" => wrk, "strategy" => strategy} = block)
      when strategy in ["random", "best-first", "platform"] and (is_list(wrk) or is_binary(wrk)) do
    block_with_atom_keys =
      for {k, v} <- block, into: %{} do
        {String.to_existing_atom(k), v}
      end

    affinity = block |> Map.get("affinity", [])

    capacity_used =
      block
      |> Map.get("invalidate", %{})
      |> Map.get("capacity_used", :infinity)
      |> then(fn x ->
        if x != :infinity do
          {n, _} = Integer.parse(x)
          n
        else
          x
        end
      end)

    max_concurrent_invocations =
      block |> Map.get("invalidate", %{}) |> Map.get("max_concurrent_invocations", :infinity)

    {:ok,
     struct(
       Data.Configurations.AAPP.Block,
       block_with_atom_keys
       |> Map.put(:affinity, affinity)
       |> Map.put(:invalidate, %{
         capacity_used: capacity_used,
         max_concurrent_invocations: max_concurrent_invocations
       })
       |> Map.put(:strategy, strategy |> String.to_existing_atom())
     )}
  end

  def parse_block(%{"workers" => wrk} = block)
      when is_list(wrk) or is_binary(wrk) do
    parse_block(block |> Map.put("strategy", "best-first"))
  end

  def parse_block(_) do
    {:error, :no_block_workers}
  end

  @doc """
  Converts a given AAPP script struct to a simple map.
  """
  @spec to_map(Data.Configurations.AAPP.t()) :: map()
  def to_map(aapp_script) do
    %{tags: tags} = outer_map = Map.from_struct(aapp_script)

    tag_maps =
      tags
      |> Map.new(fn {k, v} -> {k, v |> Map.from_struct() |> blocks_to_maps()} end)

    outer_map |> Map.put(:tags, tag_maps)
  end

  @spec blocks_to_maps(Data.Configurations.AAPP.Tag.t()) :: map()
  defp blocks_to_maps(%{blocks: blocks} = tag_map) do
    block_maps =
      blocks
      |> Enum.map(&Map.from_struct(&1))

    tag_map |> Map.put(:blocks, block_maps)
  end

  @doc """
  Builds an AAPP script from a map with string keys (assuming it has the correct structure).
  """
  @spec from_string_keys(map()) :: Data.Configurations.AAPP.t() | {:error, :unknown_construct}
  def from_string_keys(%{"tags" => tags}) do
    atom_tags = tags |> Map.new(fn {k, v} -> {k, v |> tag_from_string_keys} end)
    %Data.Configurations.AAPP{tags: atom_tags}
  end

  def from_string_keys(_) do
    {:error, :unknown_construct}
  end

  defp tag_from_string_keys(%{"blocks" => blocks, "followup" => followup}) do
    atom_followup = followup |> String.to_existing_atom()
    atom_blocks = blocks |> Enum.map(&block_from_string_keys/1)
    %Data.Configurations.AAPP.Tag{blocks: atom_blocks, followup: atom_followup}
  end

  defp block_from_string_keys(%{
         "affinity" => affinity,
         "invalidate" => invalidate,
         "strategy" => strategy,
         "workers" => workers
       }) do
    atom_invalidate =
      invalidate
      |> Map.new(fn {k, v} ->
        case v do
          "infinity" -> {String.to_existing_atom(k), :infinity}
          val -> {String.to_existing_atom(k), val}
        end
      end)

    %Data.Configurations.AAPP.Block{
      affinity: affinity,
      invalidate: atom_invalidate,
      strategy: String.to_existing_atom(strategy),
      workers: workers
    }
  end
end
