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

defmodule Core.Unit.Policies.AAPPPolicyTest do
  use ExUnit.Case, async: false

  alias Core.Adapters.AffinityTracker
  alias Core.Domain.Policies.SchedulingPolicy
  alias Data.Configurations.AAPP
  alias Data.Configurations.AAPP.Block
  alias Data.Configurations.AAPP.Tag
  alias Data.FunctionMetadata
  alias Data.FunctionStruct
  alias Data.Worker
  alias Data.Worker.Metrics

  setup do
    # AffinityTracker is already started by the application supervisor
    :ok
  end

  defp setup_aapp_test(tag, affinity) do
    config = %AAPP{
      tags: %{
        tag => %Tag{
          blocks: [
            %Block{
              workers: ["worker1", "worker2"],
              strategy: :random,
              affinity: affinity,
              invalidate: %{
                capacity_used: :infinity,
                max_concurrent_invocations: :infinity
              }
            }
          ],
          followup: :fail
        }
      }
    }

    workers = [
      %Worker{
        name: :worker1,
        long_name: "worker1",
        tag: "compute",
        resources: %Metrics{memory: %{free: 1000, total: 2000}},
        concurrent_functions: 0
      },
      %Worker{
        name: :worker2,
        long_name: "worker2",
        tag: "compute",
        resources: %Metrics{memory: %{free: 1000, total: 2000}},
        concurrent_functions: 0
      }
    ]

    function = %FunctionStruct{
      name: "test_function",
      module: "test_module",
      hash: "test_hash",
      metadata: %FunctionMetadata{tag: tag, capacity: 500}
    }

    {config, workers, function}
  end

  describe "affinity handling" do
    test "selects worker without affinity constraints" do
      {config, workers, function} = setup_aapp_test("default", [])

      result = SchedulingPolicy.select(config, workers, function, %{})
      assert {:ok, worker} = result
      assert worker.name in [:worker1, :worker2]
    end

    test "allows scheduling with affinity requirements" do
      {config, workers, function} = setup_aapp_test("impera", ["divide", "!heavy_eu"])

      AffinityTracker.track_function("worker1", "divide")

      result = SchedulingPolicy.select(config, workers, function, %{})
      assert {:ok, %Worker{}} = result

      AffinityTracker.untrack_function("worker1", "divide")
    end

    test "rejects worker with anti-affinity violations" do
      {config, workers, function} = setup_aapp_test("impera", ["!heavy_eu"])
      # Use only one worker
      workers = [List.first(workers)]

      AffinityTracker.track_function("worker1", "heavy_eu")

      result = SchedulingPolicy.select(config, workers, function, %{})
      assert {:error, :no_valid_workers} = result

      AffinityTracker.untrack_function("worker1", "heavy_eu")
    end

    test "tracks and untracks function tags" do
      worker = "test_worker"

      assert [] == AffinityTracker.get_worker_tags(worker)

      AffinityTracker.track_function(worker, "function_a")
      assert ["function_a"] == AffinityTracker.get_worker_tags(worker)

      AffinityTracker.track_function(worker, "function_b")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["function_a", "function_b"]

      assert AffinityTracker.affinity_compatible?(worker, ["function_a"])
      assert AffinityTracker.affinity_compatible?(worker, ["!function_c"])
      refute AffinityTracker.affinity_compatible?(worker, ["!function_a"])

      AffinityTracker.untrack_function(worker, "function_a")
      AffinityTracker.untrack_function(worker, "function_b")
      assert [] == AffinityTracker.get_worker_tags(worker)
    end
  end
end
