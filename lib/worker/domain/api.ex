# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

defmodule Worker.Domain.Function do
  @moduledoc """
    Function struct, passed to Fn.

    ## Fields
      - name: function name
      - image: base Docker image for the function's container
      - archive: tarball containing the function's code, will be copied into container
      - main_file: path of the function's main file inside the container
  """
  @enforce_keys [:name, :image, :archive]
  defstruct [:name, :image, :archive, :main_file]
end

defmodule Worker.Domain.Api do
  @moduledoc """
  Contains functions used to create, run and remove function containers. Side effects (e.g. docker interaction) are delegated to the functions passed as arguments.
  """
  alias Worker.Domain.Ports.Containers
  alias Worker.Domain.Ports.FunctionStorage

  @spec function_has_container?(Struct.t()) :: Boolean.t()
  def function_has_container?(%{
        name: function_name
      }) do
    case FunctionStorage.get_function_containers(function_name) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @spec prepare_container(Struct.t()) :: {:ok, String.t()} | {:error, any}
  def prepare_container(%{
        name: function_name,
        image: image_name,
        archive: archive_name,
        main_file: main_file
      }) do
    container_name = function_name <> "-funless-container"

    function = %Worker.Domain.Function{
      name: function_name,
      image: image_name,
      archive: archive_name,
      main_file: main_file
    }

    result = Containers.prepare_container(function, container_name)

    case result do
      {:ok, _} -> FunctionStorage.insert_function_container(function_name, container_name)
      _ -> nil
    end

    result
  end

  @spec run_function(Struct.t()) :: {:ok, any} | {:error, any}
  def run_function(%{
        name: function_name,
        image: image_name,
        archive: archive_name,
        main_file: main_file
      }) do
    function = %Worker.Domain.Function{
      name: function_name,
      image: image_name,
      archive: archive_name,
      main_file: main_file
    }

    containers = FunctionStorage.get_function_containers(function_name)

    case containers do
      {:ok, {_, [container_name | _]}} ->
        Containers.run_function(function, container_name)

      {:error, err} ->
        {:error, {:nocontainer, err}}
    end
  end

  # TODO: differentiate cleanup all containers from cleanup single container
  @spec cleanup(Struct.t()) :: {:ok, String.t()} | {:error, any}
  def cleanup(%{
        name: function_name,
        image: image_name,
        archive: archive_name,
        main_file: main_file
      }) do
    function = %Worker.Domain.Function{
      name: function_name,
      image: image_name,
      archive: archive_name,
      main_file: main_file
    }

    containers = FunctionStorage.get_function_containers(function_name)

    result =
      case containers do
        {:ok, {_, [container_name | _]}} ->
          Containers.cleanup(function, container_name)

        {:error, err} ->
          {:error, err}
      end

    case result do
      {:ok, container_name} ->
        FunctionStorage.delete_function_container(function_name, container_name)

      _ ->
        nil
    end

    result
  end
end
