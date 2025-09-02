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

defmodule Core.Unit.InvokerAffinityTest do
  use ExUnit.Case, async: false

  alias Core.Adapters.AffinityTracker

  describe "affinity tracking" do
    test "tracks and untracks function tags" do
      worker = "test_worker"

      assert [] = AffinityTracker.get_worker_tags(worker)

      AffinityTracker.track_function(worker, "divide")
      assert ["divide"] = AffinityTracker.get_worker_tags(worker)

      AffinityTracker.track_function(worker, "compute")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["compute", "divide"]

      AffinityTracker.untrack_function(worker, "divide")
      assert ["compute"] = AffinityTracker.get_worker_tags(worker)

      AffinityTracker.untrack_function(worker, "compute")
      assert [] = AffinityTracker.get_worker_tags(worker)
    end

    test "handles duplicate tracking" do
      worker = "test_worker_2"

      AffinityTracker.track_function(worker, "divide")
      AffinityTracker.track_function(worker, "divide")

      assert ["divide"] = AffinityTracker.get_worker_tags(worker)

      AffinityTracker.untrack_function(worker, "divide")
      assert [] = AffinityTracker.get_worker_tags(worker)
    end

    test "tracks multiple function tags" do
      worker = "test_worker_3"

      # Track regular tag
      AffinityTracker.track_function(worker, "compute")
      assert ["compute"] = AffinityTracker.get_worker_tags(worker)

      # Track another regular tag
      AffinityTracker.track_function(worker, "heavy_eu")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["compute", "heavy_eu"]

      # Track third tag
      AffinityTracker.track_function(worker, "memory_intensive")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["compute", "heavy_eu", "memory_intensive"]

      # Untrack one tag
      AffinityTracker.untrack_function(worker, "heavy_eu")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["compute", "memory_intensive"]

      # Clean up
      AffinityTracker.untrack_function(worker, "compute")
      AffinityTracker.untrack_function(worker, "memory_intensive")
      assert [] = AffinityTracker.get_worker_tags(worker)
    end

    test "affinity compatibility with proper affinity and anti-affinity checks" do
      worker = "test_worker_4"

      # Worker currently has "compute" running
      AffinityTracker.track_function(worker, "compute")

      # Should allow functions with no requirements (empty affinity list)
      assert AffinityTracker.affinity_compatible?(worker, [])

      # Should allow functions that only have anti-affinity rules that don't conflict
      assert AffinityTracker.affinity_compatible?(worker, ["!memory_intensive"])

      # Should reject if function has anti-affinity rule against what's running
      refute AffinityTracker.affinity_compatible?(worker, ["!compute"])

      # Should allow if function requires what's already running (affinity match)
      assert AffinityTracker.affinity_compatible?(worker, ["compute"])

      # Should reject if function requires something that's NOT running
      refute AffinityTracker.affinity_compatible?(worker, ["divide"])
      refute AffinityTracker.affinity_compatible?(worker, ["memory_intensive"])

      # Should work with mixed requirements
      # has compute, doesn't have memory_intensive
      assert AffinityTracker.affinity_compatible?(worker, ["compute", "!memory_intensive"])
      # has compute, doesn't have divide
      refute AffinityTracker.affinity_compatible?(worker, ["compute", "divide"])

      # Clean up
      AffinityTracker.untrack_function(worker, "compute")
    end

    test "simulates invocation lifecycle with tracking" do
      worker = "test_worker_5"

      # Initially no tags tracked
      assert [] = AffinityTracker.get_worker_tags(worker)

      # Simulate invocation start - track function tag
      function_tag = "web_service"
      AffinityTracker.track_function(worker, function_tag)
      assert [function_tag] = AffinityTracker.get_worker_tags(worker)

      # During invocation, affinity checks should work
      assert AffinityTracker.affinity_compatible?(worker, ["web_service"])  # Can schedule more web_service
      refute AffinityTracker.affinity_compatible?(worker, ["!web_service"]) # Cannot schedule anti-web_service
      refute AffinityTracker.affinity_compatible?(worker, ["batch_job"])    # Cannot schedule batch_job (missing)

      # Simulate invocation completion - untrack function tag
      AffinityTracker.untrack_function(worker, function_tag)
      assert [] = AffinityTracker.get_worker_tags(worker)

      # After completion, different scheduling decisions are possible
      assert AffinityTracker.affinity_compatible?(worker, ["batch_job"])    # Can now schedule batch_job
      assert AffinityTracker.affinity_compatible?(worker, ["!web_service"]) # Can now schedule anti-web_service
    end

    test "multiple concurrent invocations on same worker" do
      worker = "test_worker_6"

      # Start multiple invocations with different function tags
      AffinityTracker.track_function(worker, "api_server")
      AffinityTracker.track_function(worker, "compute")
      
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["api_server", "compute"]

      # Scheduling should respect current tags
      assert AffinityTracker.affinity_compatible?(worker, ["api_server"])          # Can schedule more api_server
      assert AffinityTracker.affinity_compatible?(worker, ["compute"])             # Can schedule more compute
      assert AffinityTracker.affinity_compatible?(worker, ["api_server", "compute"]) # Can schedule functions requiring both
      refute AffinityTracker.affinity_compatible?(worker, ["!api_server"])         # Cannot schedule function that avoids api_server
      refute AffinityTracker.affinity_compatible?(worker, ["!compute"])            # Cannot schedule function that avoids compute
      assert AffinityTracker.affinity_compatible?(worker, ["!batch_processing"])  # Can schedule function avoiding other tags

      # End one invocation
      AffinityTracker.untrack_function(worker, "compute")
      assert ["api_server"] = AffinityTracker.get_worker_tags(worker)

      # Functions requiring compute cannot be scheduled anymore (hard affinity)
      refute AffinityTracker.affinity_compatible?(worker, ["compute"])
      refute AffinityTracker.affinity_compatible?(worker, ["api_server", "compute"])

      # Clean up
      AffinityTracker.untrack_function(worker, "api_server")
      assert [] = AffinityTracker.get_worker_tags(worker)
      
      # Now any function can be scheduled on empty worker
      assert AffinityTracker.affinity_compatible?(worker, ["compute"])
      assert AffinityTracker.affinity_compatible?(worker, ["heavy_compute"])
    end
  end
end
