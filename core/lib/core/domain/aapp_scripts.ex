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

defmodule Core.Domain.AAPPScripts do
  @moduledoc """
  The AAPPScripts context.
  """

  import Ecto.Query, warn: false
  alias Core.Repo

  alias Core.Schemas.APPScripts.AAPP

  @doc """
  Returns the list of aapp_scripts.

  ## Examples

      iex> list_aapp_scripts()
      [%AAPP{}, ...]

  """
  def list_aapp_scripts do
    Repo.all(AAPP)
  end

  @doc """
  Gets a single aapp_script by name.

  ## Examples

      iex> get_aapp_script_by_name("some_name")
      %AAPP{}

      iex> get_aapp_script_by_name("non_existent_name")
      nil
  """
  def get_aapp_script_by_name(name) do
    Repo.get_by(AAPP, name: name)
  end

  @doc """
  Gets a single aapp_script.

  Raises `Ecto.NoResultsError` if the AAPP script does not exist.

  ## Examples

      iex> get_aapp_script!(123)
      %AAPP{}

      iex> get_aapp_script!(456)
      ** (Ecto.NoResultsError)

  """
  def get_aapp_script!(id), do: Repo.get!(AAPP, id)

  @doc """
  Creates an aapp_script.

  ## Examples

      iex> create_aapp_script(%{field: value})
      {:ok, %AAPP{}}

      iex> create_aapp_script(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_aapp_script(attrs \\ %{}) do
    %AAPP{}
    |> AAPP.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an aapp_script.

  ## Examples

      iex> update_aapp_script(aapp_script, %{field: new_value})
      {:ok, %AAPP{}}

      iex> update_aapp_script(aapp_script, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_aapp_script(%AAPP{} = aapp_script, attrs) do
    aapp_script
    |> AAPP.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an aapp_script.

  ## Examples

      iex> delete_aapp_script(aapp_script)
      {:ok, %AAPP{}}

      iex> delete_aapp_script(aapp_script)
      {:error, %Ecto.Changeset{}}

  """
  def delete_aapp_script(%AAPP{} = aapp_script) do
    Repo.delete(aapp_script)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking aapp_script changes.

  ## Examples

      iex> change_aapp_script(aapp_script)
      %Ecto.Changeset{data: %AAPP{}}

  """
  def change_aapp_script(%AAPP{} = aapp_script, attrs \\ %{}) do
    AAPP.changeset(aapp_script, attrs)
  end
end
