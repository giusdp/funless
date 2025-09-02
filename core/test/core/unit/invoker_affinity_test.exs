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

    test "tracks all tags in single list" do
      worker = "test_worker_3"

      # Track regular tag
      AffinityTracker.track_function(worker, "compute")
      assert ["compute"] = AffinityTracker.get_worker_tags(worker)

      # Track anti-affinity tag (stored with ! prefix)
      AffinityTracker.track_function(worker, "!heavy_eu")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["!heavy_eu", "compute"]

      # Track another anti-affinity tag
      AffinityTracker.track_function(worker, "!memory_intensive")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["!heavy_eu", "!memory_intensive", "compute"]

      # Untrack anti-affinity tag
      AffinityTracker.untrack_function(worker, "!heavy_eu")
      tags = AffinityTracker.get_worker_tags(worker)
      assert Enum.sort(tags) == ["!memory_intensive", "compute"]

      # Clean up
      AffinityTracker.untrack_function(worker, "compute")
      AffinityTracker.untrack_function(worker, "!memory_intensive")
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
  end
end
