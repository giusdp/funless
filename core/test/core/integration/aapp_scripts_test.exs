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

defmodule Core.AAPPScriptsTest do
  use Core.DataCase

  alias Core.Domain.AAPPScripts

  describe "aapp_scripts" do
    alias Core.Schemas.AAPPScripts.AAPP

    import Core.AAPPScriptsFixtures

    @invalid_attrs %{name: nil, script: nil}

    test "list_aapp_scripts/0 returns all aapp_scripts, with string keys instead of atoms" do
      aapp_script = aapp_script_fixture()
      %{script: script_content} = aapp_script

      assert AAPPScripts.list_aapp_scripts() == [
               aapp_script
               |> Map.put(:script, script_content |> Jason.encode!() |> Jason.decode!())
             ]
    end

    test "get_aapp_script!/1 returns the aapp_script with given id, with string keys instead of atoms" do
      aapp_script = aapp_script_fixture()
      %{script: script_content} = aapp_script

      assert AAPPScripts.get_aapp_script!(aapp_script.id) ==
               aapp_script
               |> Map.put(:script, script_content |> Jason.encode!() |> Jason.decode!())
    end

    test "get_aapp_script_by_name/1 returns the aapp_script with given name" do
      aapp_script = aapp_script_fixture()
      %{script: script_content} = aapp_script

      assert AAPPScripts.get_aapp_script_by_name(aapp_script.name) ==
               aapp_script
               |> Map.put(:script, script_content |> Jason.encode!() |> Jason.decode!())
    end

    test "get_aapp_script_by_name/1 returns nil when script not found" do
      assert AAPPScripts.get_aapp_script_by_name("nonexistent") == nil
    end

    test "create_aapp_script/1 with valid data creates a aapp_script" do
      %{script: script_content} = aapp_script_fixture()
      valid_attrs = %{name: "some aapp name", script: script_content}

      assert {:ok, %AAPP{} = aapp_script} = AAPPScripts.create_aapp_script(valid_attrs)
      assert aapp_script.name == "some aapp name"
      assert aapp_script.script == script_content
    end

    test "create_aapp_script/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = AAPPScripts.create_aapp_script(@invalid_attrs)
    end

    test "update_aapp_script/2 with valid data updates the aapp_script" do
      aapp_script = aapp_script_fixture()
      %{script: script_content} = aapp_script
      update_attrs = %{name: "some updated aapp name", script: script_content}

      assert {:ok, %AAPP{} = aapp_script} =
               AAPPScripts.update_aapp_script(aapp_script, update_attrs)

      assert aapp_script.name == "some updated aapp name"
      assert aapp_script.script == script_content
    end

    test "update_aapp_script/2 with invalid data returns error changeset" do
      aapp_script = aapp_script_fixture()
      %{script: script_content} = aapp_script

      stored_aapp_script =
        aapp_script |> Map.put(:script, script_content |> Jason.encode!() |> Jason.decode!())

      assert {:error, %Ecto.Changeset{}} =
               AAPPScripts.update_aapp_script(aapp_script, @invalid_attrs)

      assert stored_aapp_script ==
               AAPPScripts.get_aapp_script!(aapp_script.id)
    end

    test "delete_aapp_script/1 deletes the aapp_script" do
      aapp_script = aapp_script_fixture()
      assert {:ok, %AAPP{}} = AAPPScripts.delete_aapp_script(aapp_script)
      assert_raise Ecto.NoResultsError, fn -> AAPPScripts.get_aapp_script!(aapp_script.id) end
    end

    test "change_aapp_script/1 returns a aapp_script changeset" do
      aapp_script = aapp_script_fixture()
      assert %Ecto.Changeset{} = AAPPScripts.change_aapp_script(aapp_script)
    end
  end
end
