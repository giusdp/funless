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

defmodule Core.Unit.Policies.Parsers.AappParserTest do
  use ExUnit.Case, async: true

  alias Core.Domain.Policies.Parsers
  alias Data.Configurations.AAPP
  alias Data.Configurations.AAPP.Block
  alias Data.Configurations.AAPP.Tag

  describe "AAPP Parser" do
    test "parse should contain {:error, :no_block_workers} if a tag without workers is given" do
      script = File.read!("test/support/fixtures/AAPP/no_workers.yml")

      assert Parsers.AAPP.parse(script) ==
               {:error, %{"t" => {:error, [{:error, :no_block_workers}]}}}
    end

    test "parse should contain {:error, :no_blocks} if a tag without blocks is given" do
      script = File.read!("test/support/fixtures/AAPP/no_blocks.yml")

      assert Parsers.AAPP.parse(script) == {:error, %{"t2" => {:error, :no_blocks}}}
    end

    test "parse should contain {:error, :unknown_followup} if a tag includes a followup other than 'fail' or 'default'" do
      script = File.read!("test/support/fixtures/AAPP/unknown_followup.yml")

      assert Parsers.AAPP.parse(script) == {:error, %{"t" => {:error, :unknown_followup}}}
    end

    test "parse should contain {:error, :unknown_construct} if a tag defines something other than blocks and followup" do
      script = File.read!("test/support/fixtures/AAPP/unknown_construct.yml")

      assert Parsers.AAPP.parse(script) ==
               {:error, %{"construct" => {:error, :unknown_construct}}}
    end

    test "parse should return a valid AAPP struct when given a correct script (invalidate.yml)" do
      script = File.read!("test/support/fixtures/AAPP/invalidate.yml")

      assert {:ok,
              %AAPP{
                tags: %{
                  "t" => %Tag{
                    blocks: [
                      %Block{
                        affinity: [],
                        workers: ["w1", "w2"],
                        invalidate: %{
                          capacity_used: 50,
                          max_concurrent_invocations: 3
                        }
                      }
                    ],
                    followup: :fail
                  }
                }
              }} == Parsers.AAPP.parse(script)
    end

    test "parse should return a valid AAPP struct when given a correct script with simplified affinity (simple_affinity.yml)" do
      script = File.read!("test/support/fixtures/AAPP/simple_affinity.yml")

      assert {:ok,
              %AAPP{
                tags: %{
                  "producer" => %Tag{
                    blocks: [
                      %Block{
                        affinity: ["consumer", "!heavy"],
                        workers: ["worker1", "worker2"],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  },
                  "consumer" => %Tag{
                    blocks: [
                      %Block{
                        affinity: ["producer", "!heavy"],
                        workers: ["worker1", "worker2"],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      },
                      %Block{
                        affinity: ["!heavy"],
                        workers: ["worker1", "worker2"],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  },
                  "heavy" => %Tag{
                    blocks: [
                      %Block{
                        affinity: [],
                        workers: ["worker1", "worker2"],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  }
                }
              }} ===
               Parsers.AAPP.parse(script)
    end

    test "parse should return a valid AAPP struct when given the example aapp configuration" do
      script = File.read!("test/support/fixtures/AAPP/example_aapp.yml")

      assert {:ok,
              %AAPP{
                tags: %{
                  "default" => %Tag{
                    blocks: [
                      %Block{
                        affinity: [],
                        workers: "*",
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  },
                  "impera" => %Tag{
                    blocks: [
                      %Block{
                        affinity: ["divide", "!heavy_eu", "!heavy_us"],
                        workers: [
                          "workereu1",
                          "workereu2",
                          "workereu3",
                          "workerus1",
                          "workerus2",
                          "workerus3"
                        ],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  },
                  "divide" => %Tag{
                    blocks: [
                      %Block{
                        affinity: ["impera", "!heavy_eu", "!heavy_us"],
                        workers: [
                          "workereu1",
                          "workereu2",
                          "workereu3",
                          "workerus1",
                          "workerus2",
                          "workerus3"
                        ],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      },
                      %Block{
                        affinity: ["!heavy_eu", "!heavy_us"],
                        workers: [
                          "workereu1",
                          "workereu2",
                          "workereu3",
                          "workerus1",
                          "workerus2",
                          "workerus3"
                        ],
                        strategy: :random,
                        invalidate: %{
                          capacity_used: :infinity,
                          max_concurrent_invocations: :infinity
                        }
                      }
                    ],
                    followup: :fail
                  }
                }
              }} ===
               Parsers.AAPP.parse(script)
    end

    test "to_map should return the AAPP struct and its nested struct as a single map" do
      script = File.read!("test/support/fixtures/AAPP/simple_affinity.yml")
      {:ok, parsed_script} = Parsers.AAPP.parse(script)

      assert %{
               tags: %{
                 "producer" => %{
                   blocks: [
                     %{
                       affinity: ["consumer", "!heavy"],
                       workers: ["worker1", "worker2"],
                       strategy: :random,
                       invalidate: %{
                         capacity_used: :infinity,
                         max_concurrent_invocations: :infinity
                       }
                     }
                   ],
                   followup: :fail
                 },
                 "consumer" => %{
                   blocks: [
                     %{
                       affinity: ["producer", "!heavy"],
                       workers: ["worker1", "worker2"],
                       strategy: :random,
                       invalidate: %{
                         capacity_used: :infinity,
                         max_concurrent_invocations: :infinity
                       }
                     },
                     %{
                       affinity: ["!heavy"],
                       workers: ["worker1", "worker2"],
                       strategy: :random,
                       invalidate: %{
                         capacity_used: :infinity,
                         max_concurrent_invocations: :infinity
                       }
                     }
                   ],
                   followup: :fail
                 },
                 "heavy" => %{
                   blocks: [
                     %{
                       affinity: [],
                       workers: ["worker1", "worker2"],
                       strategy: :random,
                       invalidate: %{
                         capacity_used: :infinity,
                         max_concurrent_invocations: :infinity
                       }
                     }
                   ],
                   followup: :fail
                 }
               }
             } ===
               Parsers.AAPP.to_map(parsed_script)
    end

    test "from_string_keys should return an AAPP struct when fed a map with string keys" do
      script = File.read!("test/support/fixtures/AAPP/simple_affinity.yml")
      {:ok, parsed_script} = Parsers.AAPP.parse(script)

      string_keys_script =
        parsed_script |> Parsers.AAPP.to_map() |> Jason.encode!() |> Jason.decode!()

      assert parsed_script === Parsers.AAPP.from_string_keys(string_keys_script)
    end

    test "affinity parsing should handle mixed positive and negative affinity rules" do
      yaml_content = """
      - test_tag:
        - workers:
          - worker1
          - worker2
          strategy: random
          affinity:
            - "positive_tag"
            - "!negative_tag"
            - "another_positive"
      """

      {:ok, parsed} = Parsers.AAPP.parse(yaml_content)

      assert %AAPP{
               tags: %{
                 "test_tag" => %Tag{
                   blocks: [
                     %Block{
                       affinity: ["positive_tag", "!negative_tag", "another_positive"],
                       workers: ["worker1", "worker2"],
                       strategy: :random
                     }
                   ]
                 }
               }
             } = parsed
    end

    test "affinity parsing should handle empty affinity list" do
      yaml_content = """
      - test_tag:
        - workers:
          - worker1
          strategy: random
          affinity: []
      """

      {:ok, parsed} = Parsers.AAPP.parse(yaml_content)

      assert %AAPP{
               tags: %{
                 "test_tag" => %Tag{
                   blocks: [
                     %Block{
                       affinity: [],
                       workers: ["worker1"],
                       strategy: :random
                     }
                   ]
                 }
               }
             } = parsed
    end
  end
end
