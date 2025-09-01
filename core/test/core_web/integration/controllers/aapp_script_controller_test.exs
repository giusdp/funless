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

defmodule CoreWeb.AAPPScriptControllerTest do
  use CoreWeb.ConnCase

  import Core.AAPPScriptsFixtures

  alias Core.Domain.Subjects
  alias Ecto.Adapters.SQL.Sandbox

  @create_attrs %{
    file: %Plug.Upload{path: "#{__DIR__}/../../../support/fixtures/AAPP/example_aapp.yml"},
    name: "some_aapp_name"
  }

  @invalid_attrs %{name: nil, script: nil}

  setup %{conn: conn} do
    :ok = Sandbox.checkout(Core.SubjectsRepo)
    user = Subjects.get_subject_by_name("guest")

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{user.token}")

    {:ok, conn: conn}
  end

  describe "index" do
    test "lists all aapp scripts", %{conn: conn} do
      conn = get(conn, ~p"/v1/scripts/aapp")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create aapp_script" do
    test "renders aapp_script when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/v1/scripts/aapp", @create_attrs)
      assert %{"name" => name} = json_response(conn, 201)["data"]
      conn = get(conn, ~p"/v1/scripts/aapp/#{name}")

      assert %{
               "name" => "some_aapp_name",
               "content" => content
             } = json_response(conn, 200)["data"]

      # Verify the content is valid JSON containing our AAPP structure
      decoded_content = Jason.decode!(content)
      assert %{"tags" => tags} = decoded_content
      assert Map.has_key?(tags, "default")
      assert Map.has_key?(tags, "impera")
      assert Map.has_key?(tags, "divide")

      # Verify simplified affinity structure
      impera_block = get_in(tags, ["impera", "blocks"]) |> List.first()
      assert impera_block["affinity"] == ["divide", "!heavy_eu", "!heavy_us"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/v1/scripts/aapp", @invalid_attrs)
      assert json_response(conn, 400)["errors"] != %{}
    end
  end

  describe "get single aapp script" do
    setup [:create_aapp_script]

    test "renders aapp_script", %{conn: conn, aapp_script: %{name: name} = script} do
      conn = get(conn, ~p"/v1/scripts/aapp/#{name}")

      response_data = json_response(conn, 200)["data"]

      # Check the name matches
      assert response_data["name"] == script.name

      # Parse both JSON contents to compare structure rather than string equality
      expected_content = Jason.decode!(Jason.encode!(script.script))
      actual_content = Jason.decode!(response_data["content"])

      assert expected_content == actual_content
    end
  end

  describe "delete aapp_script" do
    setup [:create_aapp_script]

    test "deletes chosen aapp_script", %{conn: conn, aapp_script: %{name: name}} do
      conn = delete(conn, ~p"/v1/scripts/aapp/#{name}")
      assert response(conn, 204)

      # Verify it's deleted
      conn = get(conn, ~p"/v1/scripts/aapp/#{name}")
      assert json_response(conn, 200)["data"] == nil
    end

    test "returns not found for non-existent aapp_script", %{conn: conn} do
      conn = delete(conn, ~p"/v1/scripts/aapp/nonexistent")
      assert json_response(conn, 404)["error"] == "AAPP script not found"
    end
  end

  describe "list with existing scripts" do
    setup [:create_aapp_script]

    test "lists all aapp script names", %{conn: conn, aapp_script: %{name: name}} do
      conn = get(conn, ~p"/v1/scripts/aapp")
      response = json_response(conn, 200)["data"]
      assert is_list(response)
      assert name in response
    end
  end

  defp create_aapp_script(_) do
    aapp_script = aapp_script_fixture()
    %{aapp_script: aapp_script}
  end
end
