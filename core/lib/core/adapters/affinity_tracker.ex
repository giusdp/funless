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

defmodule Core.Adapters.AffinityTracker do
  @moduledoc """
  A GenServer that tracks function tags per worker for affinity scheduling.

  Maintains a simple ETS table: worker_name -> [running_tags]
  """
  use GenServer, restart: :permanent
  require Logger

  @affinity_tracker_server :affinity_tracker_server
  @affinity_table :affinity_tracker

  @doc """
  Track a function tag on a worker.

  ## Parameters
  - `worker_name`: the worker's long_name string
  - `function_tag`: the function's tag to track

  ## Returns
  - `:ok`
  """
  def track_function(worker_name, function_tag) do
    GenServer.call(@affinity_tracker_server, {:track_function, worker_name, function_tag})
  end

  @doc """
  Untrack a function tag from a worker.

  ## Parameters
  - `worker_name`: the worker's long_name string
  - `function_tag`: the function's tag to untrack

  ## Returns
  - `:ok`
  """
  def untrack_function(worker_name, function_tag) do
    GenServer.call(@affinity_tracker_server, {:untrack_function, worker_name, function_tag})
  end

  @doc """
  Get function tags currently running on a worker.

  ## Parameters
  - `worker_name`: the worker's long_name string

  ## Returns
  - list of function tags currently running on the worker
  """
  def get_worker_tags(worker_name) do
    case :ets.lookup(@affinity_table, worker_name) do
      [{^worker_name, running_tags}] -> running_tags
      [] -> []
    end
  end

  @doc """
  Check if a function with specific affinity requirements can be scheduled on a worker.

  ## Parameters
  - `worker_name`: the worker's long_name string
  - `affinity_list`: list of affinity rules from AAPP config

  ## Returns
  - `true` if the function can be scheduled considering current tags
  - `false` if affinity constraints are violated
  """
  def affinity_compatible?(worker_name, affinity_list) do
    current_tags_in_worker = get_worker_tags(worker_name)

    Logger.info(
      "Affinity Tracker: checking compatibility of worker #{worker_name} with tags #{inspect(current_tags_in_worker)} against affinity rules #{inspect(affinity_list)}"
    )

    {antiaffinity_rules, affinity_rules} =
      affinity_list
      |> Enum.split_with(fn rule -> String.starts_with?(rule, "!") end)

    # Check anti-affinity: if function requires !tag and worker has tag -> REJECT
    fails_antiaffinity_check =
      Enum.map(antiaffinity_rules, fn "!" <> tag -> tag end)
      |> Enum.any?(fn tag -> tag in current_tags_in_worker end)

    # Check positive affinity: enforce as hard constraint
    # Only allow initial scheduling on empty workers
    fails_affinity_check =
      case {affinity_rules, current_tags_in_worker} do
        # No affinity requirements
        {[], _} ->
          false

        # Worker has no tags
        {_required, []} ->
          true

        {required, current} ->
          # Require ALL affinity tags to be present when worker has running functions
          # if there is at least 1 required tag missing in the current tags then REJECT
          Enum.any?(required, fn tag -> tag not in current end)
      end

    Logger.info(
      "Affinity Tracker: worker #{worker_name} fails anti-aff check: #{fails_antiaffinity_check}, fails aff check: #{fails_affinity_check}"
    )

    not fails_antiaffinity_check and not fails_affinity_check
  end

  # GenServer callbacks
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @affinity_tracker_server)
  end

  @impl true
  def init(_args) do
    table = :ets.new(@affinity_table, [:set, :named_table, :protected])
    {:ok, table}
  end

  @impl true
  def handle_call({:track_function, worker_name, function_tag}, _from, table) do
    current_tags =
      case :ets.lookup(table, worker_name) do
        [{^worker_name, tags}] -> tags
        [] -> []
      end

    # Add the function tag if not already present
    updated_tags =
      if function_tag in current_tags do
        current_tags
      else
        [function_tag | current_tags]
      end

    :ets.insert(table, {worker_name, updated_tags})

    Logger.info("Affinity Tracker: tracking #{function_tag} on #{worker_name}")
    {:reply, :ok, table}
  end

  @impl true
  def handle_call({:untrack_function, worker_name, function_tag}, _from, table) do
    current_tags =
      case :ets.lookup(table, worker_name) do
        [{^worker_name, tags}] -> tags
        [] -> []
      end

    # Remove the function tag from the list
    updated_tags = List.delete(current_tags, function_tag)

    :ets.insert(table, {worker_name, updated_tags})

    Logger.info("Affinity Tracker: untracking #{function_tag} from #{worker_name}")
    {:reply, :ok, table}
  end
end
