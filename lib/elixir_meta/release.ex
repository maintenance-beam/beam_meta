defmodule ElixirMeta.Release do
  @moduledoc """
  Functions for retrieving information related to Elixir releases.

  This module does not deal with releases prior to version `1.0.0`.
  """

  use BackPort

  @type release_data :: %{
          ElixirMeta.elixir_version_key() => %{
            assets:
              nonempty_list(%{
                content_type: String.t(),
                created_at: DateTime.t(),
                id: non_neg_integer(),
                json_url: String.t(),
                name: String.t(),
                size: non_neg_integer(),
                state: String.t(),
                updated_at: DateTime.t(),
                url: String.t()
              }),
            created_at: DateTime.t(),
            id: non_neg_integer(),
            json_url: String.t(),
            prerelease?: boolean(),
            published_at: DateTime.t(),
            tarball_url: String.t(),
            url: String.t(),
            version: Version.t(),
            zipball_url: String.t()
          }
        }
  @type release_kind :: :release | :prerelease
  @type version :: Version.t() | String.t()
  @type version_requirement :: Version.Requirement.t() | String.t()

  defguardp is_version_requirement(term)
            when is_struct(term, Version.Requirement) or is_binary(term)

  # This is the minimum requirement. We do not retrieve anything prior 1.0.0
  version_requirement = Version.parse_requirement!(">= 1.0.0")

  filter_asset = fn asset when is_map(asset) ->
    {:ok, created_at, 0} = DateTime.from_iso8601(asset["created_at"])
    {:ok, updated_at, 0} = DateTime.from_iso8601(asset["updated_at"])

    %{
      content_type: asset["content_type"],
      created_at: created_at,
      id: asset["id"],
      json_url: asset["url"],
      name: asset["name"],
      size: asset["size"],
      state: asset["state"],
      updated_at: updated_at,
      url: asset["browser_download_url"]
    }
  end

  release_data =
    ElixirMetaData.releases()
    |> Enum.reduce(%{}, fn elem, acc ->
      version_string =
        elem["tag_name"]
        |> String.trim_leading("v")

      version = Version.parse!(version_string)

      if Version.match?(version, version_requirement) do
        {:ok, published_at, 0} = DateTime.from_iso8601(elem["published_at"])
        {:ok, created_at, 0} = DateTime.from_iso8601(elem["created_at"])

        Map.put(acc, version_string, %{
          assets: Enum.map(elem["assets"], &filter_asset.(&1)),
          created_at: created_at,
          id: elem["id"],
          json_url: elem["url"],
          prerelease?: version.pre != [],
          published_at: published_at,
          tarball_url: elem["tarball_url"],
          url: elem["html_url"],
          version: version,
          zipball_url: elem["zipball_url"]
        })
      else
        acc
      end
    end)

  @versions Enum.map(release_data, fn {_k, map} -> Map.get(map, :version) end)
            |> Enum.sort_by(& &1, {:asc, Version})

  @prerelease_versions release_data
                       |> Enum.filter(fn {_k, map} -> map.prerelease? end)
                       |> Enum.map(fn {_k, map} -> Map.get(map, :version) end)
                       |> Enum.sort_by(& &1, {:asc, Version})

  @release_versions release_data
                    |> Enum.reject(fn {_k, map} -> map.prerelease? end)
                    |> Enum.map(fn {_k, map} -> Map.get(map, :version) end)
                    |> Enum.sort_by(& &1, {:asc, Version})

  versions_to_strings = fn list ->
    for version <- list do
      "#{version}"
    end
  end

  @doc """
  Returns `true` if `version` is an existing Elixir prerelease (release candidate). Otherwise it returns `false`.

  `version` could be a string, or `Version` struct.

  Allowed in guard tests.

  Examples:

      iex> version = Version.parse!("1.13.0-rc.0")
      ...> ElixirMeta.Release.is_elixir_prerelease(version)
      true

      iex> ElixirMeta.Release.is_elixir_prerelease("1.13.0-rc.0")
      true

      iex> ElixirMeta.Release.is_elixir_prerelease("1.13.0")
      false

  """
  defguard is_elixir_prerelease(version)
           when (is_struct(version, Version) and version in @prerelease_versions) or
                  (is_binary(version) and
                     version in unquote(versions_to_strings.(@prerelease_versions)))

  @doc """
  Returns `true` if `version` is an existing Elixir final release. Otherwise it returns `false`.

  `version` could be a string, or `Version` struct.

  Allowed in guard tests.

  Examples:

      iex> version = Version.parse!("1.13.0")
      ...> ElixirMeta.Release.is_elixir_release(version)
      true

      iex> ElixirMeta.Release.is_elixir_release("1.13.0-rc.0")
      false

      iex> ElixirMeta.Release.is_elixir_release("1.11.10")
      false

  """
  defguard is_elixir_release(version)
           when (is_struct(version, Version) and version in @release_versions) or
                  (is_binary(version) and
                     version in unquote(versions_to_strings.(@release_versions)))

  @doc """
  Returns `true` if `version` is an existing Elixir version, whether it is a final release or a release candidate.
  Otherwise it returns `false`.

  `version` could be a string, or `Version` struct.

  Allowed in guard tests.

  Examples:

      iex> version = Version.parse!("1.13.0")
      ...> ElixirMeta.Release.is_elixir_version(version)
      true

      iex> ElixirMeta.Release.is_elixir_version("1.13.0-rc.0")
      true

      iex> ElixirMeta.Release.is_elixir_version("1.11.10")
      false

  """
  defguard is_elixir_version(version)
           when (is_struct(version, Version) and version in @versions) or
                  (is_binary(version) and version in unquote(versions_to_strings.(@versions)))

  @latest_version Enum.max(@release_versions, Version)

  @doc """
  Returns the latest stable Elixir version.
  """
  @spec latest_version() :: Version.t()
  def latest_version(), do: @latest_version

  @doc """
  Returns a map with all the prereleases since Elixir v1.0.0.

  Examples:

      ElixirMeta.Release.prereleases()
      #=> %{
        "1.10.0-rc.0" => %{
          assets: [
            %{
              content_type: "application/zip",
              created_at: ~U[2020-01-07 15:08:43Z],
              id: 17188069,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/17188069",
              name: "Docs.zip",
              size: 2119178,
              state: "uploaded",
              updated_at: ~U[2020-01-07 15:09:40Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.10.0-rc.0/Docs.zip"
            },
            %{
              content_type: "application/zip",
              created_at: ~U[2020-01-07 15:08:47Z],
              id: 17188070,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/17188070",
              name: "Precompiled.zip",
              size: 5666120,
              state: "uploaded",
              updated_at: ~U[2020-01-07 15:09:40Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.10.0-rc.0/Precompiled.zip"
            }
          ],
          created_at: ~U[2020-01-07 14:10:04Z],
          id: 22650172,
          json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/22650172",
          prerelease?: true,
          published_at: ~U[2020-01-07 15:09:40Z],
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.10.0-rc.0",
          url: "https://github.com/elixir-lang/elixir/releases/tag/v1.10.0-rc.0",
          version: #Version<1.10.0-rc.0>,
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.10.0-rc.0"
        },
        ...
      }


  """
  @spec prereleases() :: release_data()
  def prereleases() do
    # TODO: Replace with Map.filter/2 when Elixir v1.13 is exclusively supported
    Enum.reduce(release_data(), %{}, fn
      {k, map}, acc ->
        if map.prerelease? do
          Map.put(acc, k, map)
        else
          acc
        end
    end)
  end

  @doc """
  Returns a map with only final releases since Elixir v1.0.0.

  Examples:
      ElixirMeta.Release.releases()
      #=> %{
          "1.12.1" => %{
            assets: [
              %{
                content_type: "application/zip",
                created_at: ~U[2021-05-28 15:51:16Z],
                id: 37714034,
                json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714034",
                name: "Docs.zip",
                size: 5502033,
                state: "uploaded",
                updated_at: ~U[2021-05-28 15:51:54Z],
                url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Docs.zip"
              },
              %{
                content_type: "application/zip",
                created_at: ~U[2021-05-28 15:51:27Z],
                id: 37714052,
                json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714052",
                name: "Precompiled.zip",
                size: 6049663,
                state: "uploaded",
                updated_at: ~U[2021-05-28 15:51:54Z],
                url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Precompiled.zip"
              }
            ],
            created_at: ~U[2021-05-28 15:34:14Z],
            id: 43775368,
            json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/43775368",
            prerelease?: false,
            published_at: ~U[2021-05-28 15:51:54Z],
            tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.12.1",
            url: "https://github.com/elixir-lang/elixir/releases/tag/v1.12.1",
            version: #Version<1.12.1>,
            zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.12.1"
          },
          ...
        }

  """
  @spec releases() :: release_data()
  def releases() do
    # TODO: Replace with Map.reject/2 when Elixir v1.13 is exclusively supported
    Enum.reduce(release_data(), %{}, fn
      {k, map}, acc ->
        if map.prerelease? do
          acc
        else
          Map.put(acc, k, map)
        end
    end)
  end

  @doc """
  Returns a map which contains all the information that we find relevant from releases data.

  Includes data from final releases and preseleases starting from Elixir version 1.0.0.

  Examples:

      ElixirMeta.Release.release_data()
      #=> %{
        "1.12.1" => %{
          assets: [
            %{
              content_type: "application/zip",
              created_at: ~U[2021-05-28 15:51:16Z],
              id: 37714034,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714034",
              name: "Docs.zip",
              size: 5502033,
              state: "uploaded",
              updated_at: ~U[2021-05-28 15:51:54Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Docs.zip"
            },
            %{
              content_type: "application/zip",
              created_at: ~U[2021-05-28 15:51:27Z],
              id: 37714052,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714052",
              name: "Precompiled.zip",
              size: 6049663,
              state: "uploaded",
              updated_at: ~U[2021-05-28 15:51:54Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Precompiled.zip"
            }
          ],
          created_at: ~U[2021-05-28 15:34:14Z],
          id: 43775368,
          json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/43775368",
          prerelease?: false,
          published_at: ~U[2021-05-28 15:51:54Z],
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.12.1",
          url: "https://github.com/elixir-lang/elixir/releases/tag/v1.12.1",
          version: #Version<1.12.1>,
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.12.1"
        },
        ...
      }

  """
  @spec release_data() :: release_data()
  def release_data(), do: unquote(Macro.escape(release_data))

  @doc """
  Returns a map which contains all the information that we find relevant from releases data 
  that matches the `version_requirement`.

  Includes data from final releases and preseleases starting from Elixir version 1.0.0.

  `options` are options supported by `Version.match?/3`. Currently the only key supported
  is `:allow_pre` which accepts `true` or `false` values. Defaults to `true`.

  Examples:

      ElixirMeta.Release.release_data("~> 1.12", allow_pre: false)
      #=> %{
        "1.12.1" => %{
          assets: [
            %{
              content_type: "application/zip",
              created_at: ~U[2021-05-28 15:51:16Z],
              id: 37714034,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714034",
              name: "Docs.zip",
              size: 5502033,
              state: "uploaded",
              updated_at: ~U[2021-05-28 15:51:54Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Docs.zip"
            },
            %{
              content_type: "application/zip",
              created_at: ~U[2021-05-28 15:51:27Z],
              id: 37714052,
              json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/assets/37714052",
              name: "Precompiled.zip",
              size: 6049663,
              state: "uploaded",
              updated_at: ~U[2021-05-28 15:51:54Z],
              url: "https://github.com/elixir-lang/elixir/releases/download/v1.12.1/Precompiled.zip"
            }
          ],
          created_at: ~U[2021-05-28 15:34:14Z],
          id: 43775368,
          json_url: "https://api.github.com/repos/elixir-lang/elixir/releases/43775368",
          prerelease?: false,
          published_at: ~U[2021-05-28 15:51:54Z],
          tarball_url: "https://api.github.com/repos/elixir-lang/elixir/tarball/v1.12.1",
          url: "https://github.com/elixir-lang/elixir/releases/tag/v1.12.1",
          version: #Version<1.12.1>,
          zipball_url: "https://api.github.com/repos/elixir-lang/elixir/zipball/v1.12.1"
        },
        ...
      }

  """
  @spec release_data(version_requirement) :: release_data()
  def release_data(elixir_version_requirement, options \\ [])
      when is_version_requirement(elixir_version_requirement) do
    # TODO: replace with Map.filter/2 when we require Elixir 1.13 exclusively
    Enum.reduce(release_data(), %{}, fn
      {k, map}, acc ->
        if Version.match?(map.version, elixir_version_requirement, options) do
          Map.put(acc, k, map)
        else
          acc
        end
    end)
  end

  @doc """
  Returns a list with all the Elixir versions since v1.0.0.

  The list contains the versions in the `t:Version.t/0` format, sorted ascendenly.

  Examples:

      ElixirMeta.Release.versions()
      #=> [#Version<1.0.0>, #Version<1.0.1>, #Version<1.0.2>, #Version<1.0.3>, #Version<1.0.4>,
       #Version<1.0.5>, #Version<1.1.0>, #Version<1.1.1>, #Version<1.2.0>, #Version<1.2.1>,
       #Version<1.2.2>, #Version<1.2.3>, #Version<1.2.4>, #Version<1.2.5>, #Version<1.2.6>, ...]

  """
  @spec versions() :: [Version.t()]
  def versions(), do: @versions

  @doc """
  Returns a list Elixir versions since v1.0.0, according to `kind`.

  The list contains the versions in the `t:Version.t/0` format, sorted ascendenly.

  `kind` can be:
  - `:release`
  - `:prerelease`

  Examples:

      ElixirMeta.Release.versions(:release)
      #=> [#Version<1.0.0>, #Version<1.0.1>, #Version<1.0.2>, #Version<1.0.3>, #Version<1.0.4>,
           #Version<1.0.5>, #Version<1.1.0>, #Version<1.1.1>, #Version<1.2.0>, #Version<1.2.1>,
           #Version<1.2.2>, #Version<1.2.3>, #Version<1.2.4>, #Version<1.2.5>, #Version<1.2.6>, ...]

      ElixirMeta.Release.versions(:prerelease)
      #=> [#Version<1.3.0-rc.0>, #Version<1.3.0-rc.1>, #Version<1.4.0-rc.0>, #Version<1.4.0-rc.1>,
           #Version<1.5.0-rc.0>, #Version<1.5.0-rc.1>, #Version<1.5.0-rc.2>, #Version<1.6.0-rc.0>,
           #Version<1.6.0-rc.1>, #Version<1.7.0-rc.0>, #Version<1.7.0-rc.1>, #Version<1.8.0-rc.0>, ...]

  """
  @spec versions(release_kind) :: [Version.t()]
  def versions(kind)
  def versions(:release), do: @release_versions
  def versions(:prerelease), do: @prerelease_versions
end
